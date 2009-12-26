# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class.

=head1 VERSION

This document describes RDF::Trine::Parser version 0.113_02

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 $parser->parse_into_model( $base_uri, $rdf, $model );

=head1 DESCRIPTION

RDF::Trine::Parser is a base class for RDF parsers. It may be used as a factory
class for constructing parser objects by name or media type with the C<< new >>
method, or used to abstract away the logic of choosing a parser based on the
media type of RDF content retrieved over the network with the
C<< parse_url_into_model >> method.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;

our ($VERSION);
our %parser_names;
our %media_types;
BEGIN {
	$VERSION	= '0.113_02';
}

use LWP::UserAgent;
use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Parser::RDFJSON;
use RDF::Trine::Parser::RDFa;

=item C<< new ( $parser_name ) >>

Returns a new RDF::Trine::Parser object for the parser with the specified name
(e.g. "rdfxml" or "turtle"). If no parser with the specified name is found,
throws a RDF::Trine::Error::ParserError exception.

=cut

sub new {
	my $class	= shift;
	my $name	= shift;
	my $key		= lc($name);
	$key		=~ s/[^a-z]//g;
	
	if ($name eq 'guess') {
		die;
	} elsif (my $class = $parser_names{ $key }) {
		return $class->new( @_ );
	} else {
		throw RDF::Trine::Error::ParserError -text => "No parser known named $name";
	}
}

=item C<< parse_url_into_model ( $url, $model ) >>

Retrieves the content from C<< $url >> and attempts to parse the resulting RDF
into C<< $model >> using a parser chosen by the associated content media type.

=cut

sub parse_url_into_model {
	my $class	= shift;
	my $url		= shift;
	my $model	= shift;
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Trine/$RDF::Trine::VERSION" );
	
	# prefer RDF/XML or Turtle, then anything else that we've got a parser for.
	my $accept	= join(',', map { /(turtle|rdf[+]xml)/ ? "$_;q=1.0" : "$_;q=0.9" } keys %media_types);
	$ua->default_headers->push_header( 'Accept' => $accept );
	
	my $resp	= $ua->get( $url );
	unless ($resp->is_success) {
		throw RDF::Trine::Error::ParserError -text => $resp->status_line;
	}
	
	my $type	= $resp->header('content-type');
	$type		=~ s/^([^\s;]+).*/$1/;
	my $pclass	= $media_types{ $type };
	if ($pclass and $pclass->can('new')) {
		my $parser	= $pclass->new();
		my $content	= $resp->content;
		return $parser->parse_into_model( $url, $content, $model );
	} else {
		throw RDF::Trine::Error -text => "No parser found for content type $type";
	}
}

1;

__END__

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
