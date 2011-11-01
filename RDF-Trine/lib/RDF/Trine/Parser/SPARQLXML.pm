# RDF::Trine::Parser::SPARQLXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::SPARQLXML - SPARQL XML Results Format Parser

=head1 VERSION

This document describes RDF::Trine::Parser::SPARQLXML version 0.136

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'SPARQL/XML' );
 $parser->parse_bindings_string( $xml );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::SPARQLXML;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';

use URI;
use Log::Log4perl;

use RDF::Trine qw(literal);
use RDF::Trine::Parser::SPARQLXMLHandler;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Error qw(:try);
use Scalar::Util qw(blessed looks_like_number);

######################################################################

our ($VERSION, @ISA);
BEGIN {
	$VERSION				= '0.136';
	@ISA					= qw(RDF::Trine::Parser);
	$RDF::Trine::Parser::parser_names{ 'sparqlxml' }	= __PACKAGE__;
	foreach my $ext (qw(srx)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'application/sparql-results+xml';
	foreach my $type (qw(application/sparql-results+xml)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

Returns a new SPARQL XML parser.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	return bless(\%args, $class);
}

=item C<< parse_bindings_string ( $xml ) >>

Returns a RDF::Trine::Iterator object containing the data from the supplied XML
in SPARQL XML Results format.

=cut

sub parse_bindings_string {
	my $self	= shift;
	my $xml		= shift;
	my $handler	= RDF::Trine::Parser::SPARQLXMLHandler->new();
	my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
	$p->parse_string( $xml );
	my $iter	= $handler->iterator;
	return $iter;
}

=item C<< parse_bindings_file ( $fh ) >>

Returns a RDF::Trine::Iterator object containing the data from the supplied
file handle in SPARQL XML Results format.

=cut

sub parse_bindings_file {
	my $self	= shift;
	my $fh		= shift;
	my $handler	= RDF::Trine::Parser::SPARQLXMLHandler->new();
	my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
	$p->parse_file( $fh );
	my $iter	= $handler->iterator;
	return $iter;
}


1;

__END__

=back

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
