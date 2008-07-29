# RDF::Query::Algebra::Triple
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Triple - Algebra class for Triple patterns

=cut

package RDF::Query::Algebra::Triple;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra RDF::Trine::Statement);

use Data::Dumper;
use Log::Log4perl;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch sfinally);

######################################################################

our ($VERSION);
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $s, $p, $o )>

Returns a new Triple structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	foreach my $i (0 .. 2) {
		unless (defined($nodes[ $i ])) {
			$nodes[ $i ]	= RDF::Query::Node::Variable->new($node_methods[ $i ]);
		}
	}
	return $class->SUPER::new( @nodes );
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	
	my $pred	= $self->predicate;
	if ($pred->isa('RDF::Trine::Node::Resource') and $pred->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		$pred	= 'a';
	} else {
		$pred	= $pred->as_sparql( $context );
	}
	
	my $string	= sprintf(
		"%s %s %s .",
		$self->subject->as_sparql( $context ),
		$pred,
		$self->object->as_sparql( $context ),
	);
	return $string;
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	my @nodes	= $self->nodes;
	my @blanks	= grep { $_->isa('RDF::Trine::Node::Blank') } @nodes;
	return map { $_->blank_identifier } @blanks;
}

=item C<< subsumes ( $pattern ) >>

Returns true if the triple subsumes the pattern, false otherwise.

=cut

sub subsumes {
	my $self	= shift;
	my $pattern	= shift;
	return 0 unless ($pattern->isa('RDF::Trine::Statement'));
	foreach my $method (@node_methods) {
		my $snode	= $self->$method();
		next if ($snode->isa('RDF::Trine::Node::Variable'));
		my $pnode	= $pattern->$method();
		next if ($snode->equal( $pnode ));
		return 0;
	}
	return 1;
}

=item C<< bf () >>

Returns a string representing the state of the nodes of the triple (bound or free).

=cut

sub bf {
	my $self	= shift;
	my $bf		= '';
	foreach my $n ($self->nodes) {
		$bf		.= ($n->isa('RDF::Query::Node::Variable'))
				? 'f'
				: 'b';
	}
	return $bf;
}

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		my @nodes	= $self->nodes;
		@nodes	= map { $bridge->as_native( $_, $base, $ns ) } @nodes;
		my $fixed	= $class->new( @nodes );
		return $fixed;
	}
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	my $l			= Log::Log4perl->get_logger("rdf.query.algebra.triple");
	
	our $indent		= '';
	my @triple		= $self->nodes;
	
	my %bind;
	my $vars	= 0;
	my ($var, $method);
	my (@vars, @methods);
	my @methodmap	= $bridge->statement_method_map;
	
	my %map;
	my %seen;
	my $dup_var	= 0;
	my @dups;
	for my $idx (0 .. 2) {
		$l->trace( "looking at triple " . $methodmap[ $idx ]);
		my $data	= $triple[$idx];
		if (blessed($data)) {
			if ($data->isa('RDF::Query::Node::Variable') or $data->isa('RDF::Query::Node::Blank')) {
				my $tmpvar	= ($data->isa('RDF::Query::Node::Variable'))
							? $data->name
							: '__' . $data->blank_identifier;
				$map{ $methodmap[ $idx ] }	= $tmpvar;
				if ($seen{ $tmpvar }++) {
					$dup_var	= 1;
				}
				my $val		= $bound->{ $tmpvar };
				if ($bridge->is_node($val)) {
					$l->trace( "${indent}-> already have value for $tmpvar: " . $bridge->as_string( $val ) . "\n" );
					$triple[$idx]	= $val;
					$vars[$idx]		= $tmpvar;
					$methods[$idx]	= $methodmap[ $idx ];
				} else {
					++$vars;
					$l->trace( "${indent}-> found variable $tmpvar (we've seen $vars variables already)\n" );
					$triple[$idx]	= undef;
					$vars[$idx]		= $tmpvar;
					$methods[$idx]	= $methodmap[ $idx ];
				}
			}
		} else {
		}
	}
	
	my @graph;
	my $stream;
	my @streams;
	
	my $t0	= [gettimeofday];
	my $statements	= (@graph)
					? $bridge->get_named_statements( @triple[0,1,2], $graph[0], $query, $bound )
					: $bridge->get_statements( @triple[0,1,2], $query, $bound );
	if ($dup_var) {
		# there's a node in the triple pattern that is repeated (like (?a ?b ?b)), but since get_statements() can't
		# directly make that query, we're stuck filtering the triples after we get the stream back.
		my %counts;
		my $dup_key;
		for (keys %map) {
			my $val	= $map{ $_ };
			if ($counts{ $val }++) {
				$dup_key	= $val;
			}
		}
		my @dup_methods	= grep { $map{$_} eq $dup_key } @methodmap;
		$statements	= sgrep {
			my $stmt	= $_;
			if (2 == @dup_methods) {
				my ($a, $b)	= @dup_methods;
				return ($bridge->equals( $stmt->$a(), $stmt->$b() )) ? 1 : 0;
			} else {
				my ($a, $b, $c)	= @dup_methods;
				return (($bridge->equals( $stmt->$a(), $stmt->$b() )) and ($bridge->equals( $stmt->$a(), $stmt->$c() ))) ? 1 : 0;
			}
		} $statements;
	}
	
	if (my $log = $query->logger) {
		$l->debug("logging triple execution time");
		my $elapsed = tv_interval ( $t0 );
		$log->push_key_value( 'execute_time-triple', $self->as_sparql, $elapsed );
	} else {
		$l->debug("no logger present for triple execution time");
	}
	
	my $count		= 0;
	my $bf			= $self->bf;
	my $sparql		= $self->as_sparql;
	my $bindings	= smap {
		my $stmt	= $_;
		
		my $result	= { %$bound };
		foreach (0 .. $#vars) {
			my $var		= $vars[ $_ ];
			my $method	= $methods[ $_ ];
			next unless (defined($var));
			
			$l->trace("${indent}-> got variable $var = " . $bridge->as_string( $stmt->$method() ));
			if (defined($bound->{$var})) {
				$l->trace( "${indent}-> uh oh. $var has been defined more than once.");
				if ($bridge->as_string( $stmt->$method() ) eq $bridge->as_string( $bound->{$var} )) {
					$l->trace( "${indent}-> the two values match. problem avoided.");
				} else {
					$l->trace( "${indent}-> the two values don't match. this triple won't work.");
					$l->trace( "${indent}-> the existing value is " . $bridge->as_string( $bound->{$var} ));
					return ();
				}
			} else {
				$result->{ $var }	= $stmt->$method();
			}
		}
		$count++;
		return $result;
	} $statements;
	
	my $sub	= sub {
		my $r	= $bindings->next;
		return $r;
	};
	
	# add the pre-bound variables to the var list so that the stream has the correct binding_names.
	my %binding_names;
	foreach my $n (@vars, (keys %$bound)) {
		if (defined($n)) {
			$binding_names{ $n }	= 1;
		}
	}
	
	my $iter	= RDF::Trine::Iterator::Bindings->new( $sub, [keys %binding_names], bridge => $bridge );
	$iter	= sfinally {
		if (my $log = $query->logger) {
			$log->push_key_value( 'cardinality-triple', $self->as_sparql, $count );
			if (my $bf = $self->bf) {
				$log->push_key_value( 'cardinality-bf-triple', $bf, $count );
			}
		}
	} $iter;
	return $iter;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
