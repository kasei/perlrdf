# RDF::Query::Algebra::Quad
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Quad - Algebra class for Quad patterns

=cut

package RDF::Query::Algebra::Quad;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra RDF::Trine::Statement::Quad);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

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

=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	my @nodes;
	foreach my $n ($self->nodes) {
		my $blessed	= blessed($n);
		if ($blessed and $n->isa('RDF::Query::Node::Resource')) {
			my $uri	= $n->uri;
			if (ref($uri)) {
				my ($n,$l)	= @$uri;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base );
				push(@nodes, $resolved);
			} else {
				push(@nodes, $n);
			}
		} elsif ($blessed and $n->isa('RDF::Query::Node::Literal')) {
			my $node	= $n;
			my $dt	= $node->literal_datatype;
			if (ref($dt)) {
				my ($n,$l)	= @$dt;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base );
				my $lit			= RDF::Query::Node::Literal->new( $node->literal_value, undef, $resolved->uri_value );
				push(@nodes, $lit);
			} else {
				push(@nodes, $node);
			}
		} else {
			push(@nodes, $n);
		}
	}
	return $class->new( @nodes );
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
	my $l			= Log::Log4perl->get_logger("rdf.query.algebra.quad");
	
	our $indent		= '';
	my @quad		= $self->nodes;
	
	my %bind;
	my $vars	= 0;
	my ($var, $method);
	my (@vars, @methods);
	my @methodmap	= qw(subject predicate object context);
	
	my %map;
	my %seen;
	my $dup_var	= 0;
	my @dups;
	for my $idx (0 .. 3) {
		$l->debug("looking at triple " . $methodmap[ $idx ]);
		my $data	= $quad[$idx];
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
					$l->debug("${indent}-> already have value for $tmpvar: " . $bridge->as_string( $val ));
					$quad[$idx]	= $val;
				} else {
					++$vars;
					$l->debug("${indent}-> found variable $tmpvar (we've seen $vars variables already)");
					$quad[$idx]	= undef;
					$vars[$idx]		= $tmpvar;
					$methods[$idx]	= $methodmap[ $idx ];
				}
			}
		} else {
		}
	}
	
	my $stream;
	my @streams;
	
	$l->debug("QUAD EXECUTING: " . Dumper(\@quad));
	my ($s, $p, $o, $c)	= @quad;
	my $statements	= $bridge->get_named_statements( $s, $p, $o, $c, $query, $bound );
	$l->debug("-> statements stream: $statements");
	
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
	
	my $bindings	= smap {
		my $stmt	= $_;
		
		my $result	= { %$bound };
		foreach (0 .. $#vars) {
			my $var		= $vars[ $_ ];
			my $method	= $methods[ $_ ];
			next unless (defined($var));
			
			$l->debug("${indent}-> got variable $var = " . $bridge->as_string( $stmt->$method() ));
			if (defined($bound->{$var})) {
				$l->debug("${indent}-> uh oh. $var has been defined more than once.\n");
				if ($bridge->as_string( $stmt->$method() ) eq $bridge->as_string( $bound->{$var} )) {
					$l->debug("${indent}-> the two values match. problem avoided.");
				} else {
					$l->debug("${indent}-> the two values don't match. this triple won't work.");
					$l->debug("${indent}-> the existing value is" . $bridge->as_string( $bound->{$var} ) . "\n");
					return ();
				}
			} else {
				$result->{ $var }	= $stmt->$method();
			}
		}
		$result;
	} $statements;
	
	my $sub	= sub {
		my $r	= $bindings->next;
		return $r;
	};
	return RDF::Trine::Iterator::Bindings->new( $sub, [grep defined, @vars], bridge => $bridge );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
