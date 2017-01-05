# RDF::Query::Algebra::Extend
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Extend - Algebra class for extending the variable projection

=head1 VERSION

This document describes RDF::Query::Algebra::Extend version 2.918.

=cut

package RDF::Query::Algebra::Extend;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(reftype blessed);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<< new ( $pattern, \@vars_and_exprs ) >>

Returns a new Extend structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $vars	= shift;
	unless (reftype($vars) eq 'ARRAY' and not(blessed($vars))) {
		throw RDF::Query::Error::MethodInvocationError -text => "Variable list in RDF::Query::Algebra::Extend constructor must be an ARRAY reference";
	}
	my @vars	= grep { $_->isa('RDF::Query::Expression::Alias') } @$vars;
	return bless( [ $pattern, \@vars ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $vars	= $self->vars;
	return ($pattern, $vars);
}

=item C<< pattern >>

Returns the pattern to be sorted.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< vars >>

Returns the vars to be extended.

=cut

sub vars {
	my $self	= shift;
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my $vars	= join(' ',
					map {
						($_->isa('RDF::Query::Node::Variable')) ? '?' . $_->name : $_->sse( $context )
					} @{ $self->vars }
				);
	return sprintf(
		"(extend (%s)\n${prefix}${indent}%s\n${prefix})",
		$vars,
		$self->pattern->sse( $context, "${prefix}${indent}" ),
	);
}

sub _from_sse {
	my $class	= shift;
	my $context	= $_[1];
	for ($_[0]) {
		if (m/^[(]extend\s+[(]\s*/) {
			my @nodes;
			s/^[(]extend\s+[(]\s*//;
			do {
				push(@nodes, RDF::Trine::Node->from_sse( $_[0], $context ));
			} until (m/\s*[)]/);
			if (m/^\s*[)]/) {
				s/^\s*[)]\s*//;
			} else {
				throw RDF::Trine::Error -text => "Cannot parse end-of-extend-vars from SSE string: >>$_<<";
			}
			
			my ($pattern)	= RDF::Query::Algebra->from_sse( $context, $_[0] );
			
			if (m/^\s*[)]/) {
				s/^\s*[)]\s*//;
				return RDF::Query::Algebra::Extend->new( $pattern, \@nodes );
			} else {
				throw RDF::Trine::Error -text => "Cannot parse end-of-extend from SSE string: >>$_<<";
			}
		} else {
			throw RDF::Trine::Error -text => "Cannot parse extend from SSE string: >>$_<<";
		}
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift;
	
	if ($context->{ skip_extend }) {
		$context->{ skip_extend }--;
		return $self->pattern->as_sparql( $context, $indent );
	}
	
	my $pattern	= $self->pattern;
	my $vlist	= $self->vars;
	my (@vars);
	foreach my $k (@$vlist) {
		if ($k->isa('RDF::Query::Expression')) {
			push(@vars, $k->as_sparql({}, ''));
		} elsif ($k->isa('RDF::Query::Node::Variable')) {
			push(@vars, '?' . $k->name);
		} else {
			push(@vars, $k);
		}
	}
	
	my $ggp		= $pattern->as_sparql( $context, $indent );
	my $sparql	= $ggp;
	foreach my $v (@vars) {
		$sparql	.=	"\n${indent}BIND" . $v;
	}
	return $sparql;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		vars		=> [ map { $_->as_hash } @{ $self->vars } ],
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'PROJECT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= $self->pattern->referenced_variables;
	foreach my $v (@{ $self->vars }) {
		if ($v->isa('RDF::Query::Node::Variable')) {
			push(@vars, $v->name);
		} else {
			push(@vars, $v->referenced_variables);
		}
	}
	return RDF::Query::_uniq(@vars);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	my @vars;
	push(@vars, $self->pattern->potentially_bound);
	foreach my $v (@{ $self->vars }) {
		if ($v->isa('RDF::Query::Node::Variable')) {
			push(@vars, $v->name);
		} else {
			push(@vars, $v->potentially_bound);
		}
	}
	return RDF::Query::_uniq(@vars);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

=item C<< is_solution_modifier >>

Returns true if this node is a solution modifier.

=cut

sub is_solution_modifier {
	return 1;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
