# RDF::Query::Algebra::Triple
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Triple - Algebra class for Triple patterns

=cut

package RDF::Query::Algebra::Triple;

use strict;
use warnings;
use base qw(RDF::Query::Algebra RDF::Trine::Statement);
use constant DEBUG	=> 0;

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=cut

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
		if (blessed($n) and $n->isa('RDF::Query::Node::Resource')) {
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
		} elsif (blessed($n) and $n->isa('RDF::Query::Node::Literal')) {
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

=item C<< fixup ( $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	my @nodes	= map { $bridge->as_native( $_, $base, $ns ) } $self->nodes;
	my $fixed	= $class->new( @nodes );
	return $fixed;
}

=item C<< clone >>

=cut

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my @nodes	= $self->nodes;
	foreach my $i (0 .. 2) {
		my $n	= $nodes[ $i ];
		if ($n->isa('RDF::Query::Node::Variable')) {
			my $name	= $n->name;
			if (my $value = $bound->{ $name }) {
				$nodes[ $i ]	= $value;
			}
		}
	}
	return $class->new( @nodes );
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
	
	our $indent;
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
		_debug( "looking at triple " . $methodmap[ $idx ] ) if (DEBUG);
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
					_debug( "${indent}-> already have value for $tmpvar: " . $bridge->as_string( $val ) . "\n" ) if (DEBUG);
					$triple[$idx]	= $val;
				} else {
					++$vars;
					_debug( "${indent}-> found variable $tmpvar (we've seen $vars variables already)\n" ) if (DEBUG);
					$triple[$idx]	= undef;
					$vars[$idx]		= $tmpvar;
					$methods[$idx]	= $methodmap[ $idx ];
				}
			}
		} else {
		}
	}
	
	my @graph;
	if (blessed($context) and $context->isa('RDF::Query::Node::Variable')) {
		# if we're in a GRAPH ?var {} block...
		my $context_var	= $context->name;
		my $graph		= $bound->{ $context_var };
		if ($graph) {
			# and ?var has already been bound, get the bound value and pass that on
			@graph	= $graph;
		}
	} elsif ($bridge->is_node( $context )) {
		# if we're in a GRAPH <uri> {} block, just pass it on
		@graph	= $context;
	}
	
	my $stream;
	my @streams;
	
	# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# 	warn ">>> TRIPLE:\n";
# 	foreach my $n (@triple, @graph) {
# 		if (blessed($n)) {
# 			warn $bridge->as_string( $n ) . "\n";
# 		} else {
# 			warn "(undef)\n";
# 		}
# 	}
	# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	
	my $statments	= $bridge->get_statements( @triple, @graph );
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
		$statments	= sgrep {
			my $stmt	= $_;
			if (2 == @dup_methods) {
				my ($a, $b)	= @dup_methods;
				return ($bridge->equals( $stmt->$a(), $stmt->$b() )) ? 1 : 0;
			} else {
				my ($a, $b, $c)	= @dup_methods;
				return (($bridge->equals( $stmt->$a(), $stmt->$b() )) and ($bridge->equals( $stmt->$a(), $stmt->$c() ))) ? 1 : 0;
			}
		} $statments;
	}
	
	my $bindings	= smap {
		my $stmt	= $_;
		
		my $result	= { %$bound };
		foreach (0 .. $#vars) {
			my $var		= $vars[ $_ ];
			my $method	= $methods[ $_ ];
			next unless (defined($var));
			
			_debug( "${indent}-> got variable $var = " . $bridge->as_string( $stmt->$method() ) . "\n" ) if (DEBUG);
			if (defined($bound->{$var})) {
				_debug( "${indent}-> uh oh. $var has been defined more than once.\n" ) if (DEBUG);
				if ($bridge->as_string( $stmt->$method() ) eq $bridge->as_string( $bound->{$var} )) {
					_debug( "${indent}-> the two values match. problem avoided.\n" ) if (DEBUG);
				} else {
					_debug( "${indent}-> the two values don't match. this triple won't work.\n" ) if (DEBUG);
					_debug( "${indent}-> the existing value is" . $bridge->as_string( $bound->{$var} ) . "\n" ) if (DEBUG);
					return ();
				}
			} else {
				$result->{ $var }	= $stmt->$method();
			}
		}
		$result;
	} $statments;
	
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
