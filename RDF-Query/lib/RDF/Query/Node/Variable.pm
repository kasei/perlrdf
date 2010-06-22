# RDF::Query::Node::Variable
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Variable - RDF Node class for variables

=head1 VERSION

This document describes RDF::Query::Node::Variable version 3.000_01, released 30 January 2010.

=cut

package RDF::Query::Node::Variable;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Variable);

use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '3.000_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new ( $name ) >>

Returns a new variable object.

=cut

my $COUNTER	= 0;
sub new {
	my $class	= shift;
	my $name	= shift;
	unless (defined($name)) {
		$name	= 'v' . time() . 'r' . $COUNTER++;
	}
	return $class->SUPER::new( $name );
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	return $self->sse;
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> 'node',
		variable	=> $self->name,
	};
}

package RDF::Query::Node::Variable::ExpressionProxy;

use strict;
use warnings;
use base qw(RDF::Query::Node::Variable);

=begin private

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my $name	= shift;
	my $self	= $class->SUPER::new( $name );
	return $self;
}

=item C<< as_sparql >>

=cut

sub as_sparql {
	my $self	= shift;
	return $self->name;
}

=end private

=cut

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
