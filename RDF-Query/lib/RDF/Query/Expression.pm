# RDF::Query::Expression
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression - Class for Expr expressions

=head1 VERSION

This document describes RDF::Query::Expression version 2.910.

=cut

package RDF::Query::Expression;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $op, @operands )>

Returns a new Expr structure.

=cut

sub new {
	my $class	= shift;
	my $op		= shift;
	my @operands	= @_;
	return bless( [ $op, @operands ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->op, $self->operands);
}

=item C<< op >>

Returns the operator of the expression.

=cut

sub op {
	my $self	= shift;
	return $self->[0];
}

=item C<< operands >>

Returns a list of the operands of the expression.

=cut

sub operands {
	my $self	= shift;
	return @{ $self }[ 1 .. $#{ $self } ];
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(%s %s)',
		$self->op,
		join(' ', map { $_->sse( $context ) } $self->operands),
	);
}

=item C<< explain >>

Returns a string serialization of the expression appropriate for display on the
command line. This method is primarily used by the C<< explain >> method of
the subclasses of RDF::Query::Plan.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift;
	my $count	= shift;
	my $indent	= $s x $count;
	my $type	= $self->op;
	my $string	= "${indent}${type}\n";
	foreach my $p ($self->operands) {
		$string	.= $p->explain( $s, $count+1 );
	}
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'EXPR';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @ops		= $self->operands;
	my @vars;
	foreach my $o (@ops) {
		if ($o->isa('RDF::Query::Node::Variable')) {
			push(@vars, $o->name);
		} elsif ($o->isa('RDF::Query::Expression')) {
			push(@vars, $o->referenced_variables);
		}
	}
	return RDF::Query::_uniq(@vars);
}

=item C<< nonaggregated_referenced_variables >>

Returns a list of the variable names used in this algebra expression except
those used as aliases for aggregate operations.

=cut

sub nonaggregated_referenced_variables {
	my $self	= shift;
	my @ops		= $self->operands;
	my @vars;
	foreach my $o (@ops) {
		if ($o->isa('RDF::Query::Node::Variable::ExpressionProxy')) {
		} elsif ($o->isa('RDF::Query::Node::Variable')) {
			push(@vars, $o->name);
		} elsif ($o->isa('RDF::Query::Expression')) {
			push(@vars, $o->nonaggregated_referenced_variables);
		}
	}
	return RDF::Query::_uniq(@vars);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
