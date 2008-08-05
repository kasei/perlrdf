# RDF::Query::ExecutionContext
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::ExecutionContext - Query execution context

=head1 METHODS

=over 4

=cut

package RDF::Query::ExecutionContext;

use strict;
use warnings;

=item C<< new ( model => $model, query => $query, bound => \%bound ) >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self	= bless( { %args }, $class );
	return $self;
}

sub model {
	my $self	= shift;
	return $self->{model};
}

sub query {
	my $self	= shift;
	return $self->{query};
}

sub bound {
	my $self	= shift;
	return $self->{bound} || {};
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
