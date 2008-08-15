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

=item C<< copy ( %new_args ) >>

=cut

sub copy {
	my $self	= shift;
	my %args	= @_;
	my $class	= ref($self);
	my %data	= %{ $self };
	return $class->new( %data, %args );
}

=item C<< model >>

=cut

sub model {
	my $self	= shift;
	return $self->{model};
}

=item C<< query >>

=cut

sub query {
	my $self	= shift;
	return $self->{query};
}

=item C<< bound >>

=cut

sub bound {
	my $self	= shift;
	return $self->{bound} || {};
}

=item C<< base >>

=cut

sub base {
	my $self	= shift;
	return $self->{base} || {};
}

=item C<< ns >>

=cut

sub ns {
	my $self	= shift;
	return $self->{ns} || {};
}

=item C<< logger >>

=cut

sub logger {
	my $self	= shift;
	return $self->{logger};
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
