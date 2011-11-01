# RDF::Trine::Iterator::SAXHandler
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::SAXHandler - SAX Handler for parsing SPARQL XML Results format

=head1 VERSION

This document describes RDF::Trine::Iterator::SAXHandler version 0.136

=head1 SYNOPSIS

    use RDF::Trine::Iterator::SAXHandler;
    my $handler = RDF::Trine::Iterator::SAXHandler->new();
    my $p = XML::SAX::ParserFactory->parser(Handler => $handler);
    $p->parse_file( $string );
    my $iter = $handler->iterator;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<XML::SAX::Base> class.

=cut

package RDF::Trine::Iterator::SAXHandler;

use strict;
use warnings;
use Scalar::Util qw(refaddr);

our ($VERSION, @ISA);
BEGIN {
	$VERSION	= '0.136';
	@ISA		= qw(RDF::Trine::Parser::SPARQLXMLHandler);
}


1;

__END__

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
