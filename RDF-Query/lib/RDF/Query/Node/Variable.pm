# RDF::Query::Node::Variable
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Variable - RDF Node class for variables

=head1 VERSION

This document describes RDF::Query::Node::Variable version 2.910.

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
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Node> and L<RDF::Trine::Node::Variable> classes.

=over 4

=cut

use overload	'""'	=> sub { $_[0]->sse };

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
use Scalar::Util qw(blessed refaddr);

=begin private

=item C<< new >>

=cut

{my %vars;
sub new {
	my $class	= shift;
	my $name	= shift;
	my @vars	= @_;
	my $self	= $class->SUPER::new( $name );
	if (@vars) {
		$vars{ refaddr($self) }	= [map {blessed($_) ? $_ : RDF::Query::Node::Variable->new($_)} @vars];
	}
	return $self;
}

=item C<< as_sparql >>

=cut

sub as_sparql {
	my $self	= shift;
	return $self->name;
}

=item C<< referenced_variables >>

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= map { blessed($_) ? $_->name : $_ } @{ $vars{ refaddr($self) } || [] };
	return RDF::Query::_uniq(@vars);
}

sub nonaggregated_referenced_variables {
	return;
}

sub DESTROY {
	my $self	= shift;
	delete $vars{ refaddr($self) };
}
}

=end private

=cut

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
