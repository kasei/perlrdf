# RDF::Trine::Iterator::JSONHandler
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::JSONHandler - JSON Handler for parsing SPARQL JSON Results format

=head1 VERSION

This document describes RDF::Trine::Iterator::JSONHandler version 0.136

=head1 SYNOPSIS

 use RDF::Trine::Iterator::JSONHandler;
 my $handler = RDF::Trine::Iterator::JSONHandler->new();
 my $iter = $handler->parse( $json );

=head1 METHODS

=over 4

=cut

package RDF::Trine::Iterator::JSONHandler;

use strict;
use warnings;
use Scalar::Util qw(refaddr);

use JSON;
use Data::Dumper;
use RDF::Trine::VariableBindings;

our ($VERSION, @ISA);
BEGIN {
	$VERSION	= '0.136';
	@ISA	= qw(RDF::Trine::Parser::SPARQLJSON);
}

=item C<< parse ( $json ) >>

Returns a RDF::Trine::Iterator object containing the data from the supplied JSON
in JSON SPARQL Results format.

=cut

sub parse {
	my $self	= shift;
	my $json	= shift;
	return $self->parse_bindings_string( $json );
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
