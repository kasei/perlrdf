# RDF::Trine::Pattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Pattern - Class for BasicGraphPattern patterns

=head1 VERSION

This document describes RDF::Trine::Pattern version 0.119

=cut

package RDF::Trine::Pattern;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.119';
}

######################################################################

=head1 METHODS

=over 4

=item C<< new ( @triples ) >>

Returns a new BasicGraphPattern structure.

=cut

sub new {
	my $class	= shift;
	my @triples	= @_;
	foreach my $t (@triples) {
		unless (blessed($t) and $t->isa('RDF::Trine::Statement')) {
			throw RDF::Trine::Error -text => "Patterns belonging to a BGP must be triples";
		}
	}
	return bless( [ @triples ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->triples);
}

=item C<< triples >>

Returns a list of triples belonging to this BGP.

=cut

sub triples {
	my $self	= shift;
	return @$self;
}

=item C<< type >>

=cut

sub type {
	return 'BGP';
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(bgp %s)',
		join(' ', map { $_->sse( $context ) } $self->triples)
	);
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->referenced_variables } $self->triples);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->definite_variables } $self->triples);
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->triples );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->triples );
}

=item C<< subsumes ( $statement ) >>

Returns true if the pattern will subsume the $statement when matched against a
triple store.

=cut

sub subsumes {
	my $self	= shift;
	my $st		= shift;
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.pattern");
	my @triples	= $self->triples;
	foreach my $t (@triples) {
		if ($t->subsumes( $st )) {
			$l->debug($self->sse . " \x{2292} " . $st->sse);
			return 1;
		}
	}
	return 0;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
