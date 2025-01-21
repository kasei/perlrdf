# RDF::Query::Algebra
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra - Base class for Algebra expressions

=head1 VERSION

This document describes RDF::Query::Algebra version 2.918.

=head1 METHODS

=over 4

=cut

package RDF::Query::Algebra;

our (@ISA, @EXPORT_OK);
BEGIN {
	our $VERSION	= '2.918';
	
	require Exporter;
	@ISA		= qw(Exporter);
	@EXPORT_OK	= qw(triple bgp ggp);
}

use strict;
use warnings;
no warnings 'redefine';

use Set::Scalar;
use Scalar::Util qw(blessed);
use Data::Dumper;

use RDF::Query::Expression;
use RDF::Query::Expression::Alias;
use RDF::Query::Expression::Nary;
use RDF::Query::Expression::Binary;
use RDF::Query::Expression::Unary;
use RDF::Query::Expression::Function;

use RDF::Query::Algebra::BasicGraphPattern;
use RDF::Query::Algebra::Construct;
use RDF::Query::Algebra::Filter;
use RDF::Query::Algebra::GroupGraphPattern;
use RDF::Query::Algebra::Optional;
use RDF::Query::Algebra::Triple;
use RDF::Query::Algebra::Quad;
use RDF::Query::Algebra::Union;
use RDF::Query::Algebra::NamedGraph;
use RDF::Query::Algebra::Service;
use RDF::Query::Algebra::TimeGraph;
use RDF::Query::Algebra::Aggregate;
use RDF::Query::Algebra::Sort;
use RDF::Query::Algebra::Limit;
use RDF::Query::Algebra::Offset;
use RDF::Query::Algebra::Distinct;
use RDF::Query::Algebra::Path;
use RDF::Query::Algebra::Project;
use RDF::Query::Algebra::Extend;
use RDF::Query::Algebra::SubSelect;
use RDF::Query::Algebra::Load;
use RDF::Query::Algebra::Clear;
use RDF::Query::Algebra::Update;
use RDF::Query::Algebra::Minus;
use RDF::Query::Algebra::Sequence;
use RDF::Query::Algebra::Create;
use RDF::Query::Algebra::Copy;
use RDF::Query::Algebra::Move;
use RDF::Query::Algebra::Table;

use constant SSE_TAGS	=> {
	'BGP'					=> 'RDF::Query::Algebra::BasicGraphPattern',
	'constant'				=> 'RDF::Query::Algebra::Constant',
	'construct'				=> 'RDF::Query::Algebra::Construct',
	'distinct'				=> 'RDF::Query::Algebra::Distinct',
	'filter'				=> 'RDF::Query::Algebra::Filter',
	'limit'					=> 'RDF::Query::Algebra::Limit',
	'namedgraph'			=> 'RDF::Query::Algebra::NamedGraph',
	'offset'				=> 'RDF::Query::Algebra::Offset',
	'project'				=> 'RDF::Query::Algebra::Project',
	'quad'					=> 'RDF::Query::Algebra::Quad',
	'service'				=> 'RDF::Query::Algebra::Service',
	'sort'					=> 'RDF::Query::Algebra::Sort',
	'triple'				=> 'RDF::Query::Algebra::Triple',
	'union'					=> 'RDF::Query::Algebra::Union',
	'join'					=> 'RDF::Query::Algebra::GroupGraphPattern',
	'leftjoin'				=> 'RDF::Query::Algebra::Optional',
};

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return $self->referenced_variables;
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	my @list;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			my @blanks	= $arg->referenced_blanks;
			push(@list, @blanks);
		}
	}
	return RDF::Query::_uniq(@list);
}

=item C<< referenced_functions >>

Returns a list of the Function URIs used in this algebra expression.

=cut

sub referenced_functions {
	my $self	= shift;
	my @list;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg)) {
			if ($arg->isa('RDF::Query::Expression::Function')) {
				push(@list, $arg->uri);
			} elsif ($arg->isa('RDF::Query::Algebra')) {
				my @funcs	= $arg->referenced_functions;
				push(@list, @funcs);
			}
		}
	}
	return RDF::Query::_uniq(@list);
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			$arg->check_duplicate_blanks();
		}
	}
	
	return 1;
}

sub _referenced_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push( @data, $arg->_referenced_blanks );
		}
	}
	return @data;
}

=item C<< qualify_uris ( \%namespaces, $base_uri ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base_uri	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->qualify_uris( $ns, $base_uri ));
		} elsif (blessed($arg) and $arg->isa('RDF::Query::Node::Resource')) {
			my $uri	= $arg->uri_value;
			if (ref($uri)) {
				$uri	= join('', $ns->{ $uri->[0] }, $uri->[1]);
				$arg	= RDF::Query::Node::Resource->new( $uri );
			}
			push(@args, $arg);
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->bind_variables( $bound ));
		} elsif (blessed($arg) and $arg->isa('RDF::Trine::Node::Variable') and exists($bound->{ $arg->name })) {
			push(@args, $bound->{ $arg->name });
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

=item C<< is_solution_modifier >>

Returns true if this node is a solution modifier.

=cut

sub is_solution_modifier {
	return 0;
}

=item C<< subpatterns_of_type ( $type [, $block] ) >>

Returns a list of Algebra patterns matching C<< $type >> (tested with C<< isa >>).
If C<< $block >> is given, then matching stops descending a subtree if the current
node is of type C<< $block >>, continuing matching on other subtrees.
This list includes the current algebra object if it matches C<< $type >>, and is
generated in infix order.

=cut

sub subpatterns_of_type {
	my $self	= shift;
	my $type	= shift;
	my $block	= shift;
	
	return if ($block and $self->isa($block));
	
	my @patterns;
	push(@patterns, $self) if ($self->isa($type));
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@patterns, $arg->subpatterns_of_type($type, $block));
		} elsif (blessed($arg) and $arg->isa('RDF::Query')) {
			my $pattern = $arg->pattern;
			push(@patterns, $pattern->subpatterns_of_type($type, $block));
		}
	}
	return @patterns;
}

=item C<< from_sse ( $sse, \%context ) >>

Given an SSE serialization, returns the corresponding algebra expression.

=cut

sub from_sse {
	my $class	= shift;
	my $context	= $_[1];
	if (substr($_[0], 0, 1) eq '(') {
		for ($_[0]) {
			if (my ($tag) = m/^[(](\w+)/) {
				if ($tag eq 'prefix') {
					s/^[(]prefix\s*[(]\s*//;
					my $c	= { %{ $context || {} } };
					while (my ($ns, $iri) = m/^[(](\S+):\s*<([^>]+)>[)]/) {
						s/^[(](\S+):\s*<([^>]+)>[)]\s*//;
						$c->{namespaces}{ $ns }	= $iri;
						$context	= $c;
					}
					s/^[)]\s*//;
					my $alg	= $class->from_sse( $_, $c );
					s/^[)]\s*//;
					return $alg;
				}
				
				if (my $class = SSE_TAGS->{ $tag }) {
					if ($class->can('_from_sse')) {
						return $class->_from_sse( $_, $context );
					} else {
						s/^[(](\w+)\s*//;
						my @nodes;
						while (my $alg = $class->from_sse( $_, $context )) {
							push(@nodes, $alg);
						}
						return $class->new( @nodes );
					}
				} else {
					throw RDF::Query::Error -text => "Unknown SSE tag '$tag' in SSE string: >>$_<<";
				}
			} else {
				throw RDF::Trine::Error -text => "Cannot parse pattern from SSE string: >>$_<<";
			}
		}
	} else {
		return;
	}
}

=back

=head1 FUNCTIONS

=over 4

=item C<< triple ( $subj, $pred, $obj ) >>

Returns a RDF::Query::Algebra::Triple object with the supplied node objects.

=cut

sub triple {
	my @nodes	= @_[0..2];
	return RDF::Query::Algebra::Triple->new( @nodes );
}

=item C<< bgp ( @triples ) >>

Returns a RDF::Query::Algebra::BasicGraphPattern object with the supplied triples.

=cut

sub bgp {
	my @triples	= @_;
	return RDF::Query::Algebra::BasicGraphPattern->new( @triples );
}

=item C<< ggp ( @patterns ) >>

Returns a RDF::Query::Algebra::GroupGraphPattern object with the supplied algebra patterns.

=cut

sub ggp {
	my @patterns	= @_;
	return RDF::Query::Algebra::GroupGraphPattern->new( @patterns );
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
