# RDF::Query::Algebra::Move
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Move - Algebra class for MOVE operations

=head1 VERSION

This document describes RDF::Query::Algebra::Move version 2.917.

=cut

package RDF::Query::Algebra::Move;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype refaddr);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
my %TRIPLE_LABELS;
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.917';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $from, $to, $silent )>

Returns a new MOVE structure.

=cut

sub new {
	my $class	= shift;
	my $from	= shift;
	my $to		= shift;
	my $silent	= shift || 0;
	return bless([$from, $to, $silent], $class);
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->from, $self->to, $self->silent);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $from	= $self->from;
	my $to		= $self->to;
	for ($from, $to) {
		if ($_->isa('RDF::Trine::Node::Nil')) {
			$_	= 'DEFAULT';
		} else {
			$_	= '<' . $_->uri_value . '>';
		}
	}
	
	my $string	= sprintf( "MOVE %s%s TO %s", ($self->silent ? 'SILENT ' : ''), $from, $to );
	return $string;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $from	= $self->from;
	my $to		= $self->to;
	for ($from, $to) {
		if ($_->isa('RDF::Trine::Node::Nil')) {
			$_	= 'DEFAULT';
		} else {
			$_	= '<' . $_->uri_value . '>';
		}
	}
	my $string	= sprintf( "(move%s %s %s)", ($self->silent ? '-silent' : ''), $from, $to );
	return $string;
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	return;
}

=item C<< referenced_variables >>

=cut

sub referenced_variables {
	my $self	= shift;
	return;
}

=item C<< from >>

=cut

sub from {
	my $self	= shift;
	return $self->[0];
}

=item C<< to >>

=cut

sub to {
	my $self	= shift;
	return $self->[1];
}

=item C<< silent >>

=cut

sub silent {
	my $self	= shift;
	return $self->[2];
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
