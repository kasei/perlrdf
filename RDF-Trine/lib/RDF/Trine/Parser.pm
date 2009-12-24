# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class.

=head1 VERSION

This document describes RDF::Trine::Parser version 0.112

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 $parser->parse_into_model( $base_uri, $rdf, $model );

=head1 DESCRIPTION

...

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
	$VERSION	= '0.112';
}

use LWP::UserAgent;
use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Parser::RDFJSON;


=item C<< new ( $parser_name ) >>

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

sub parse_url_into_model {
	my $class	= shift;
	my $url		= shift;
	my $model	= shift;
	my $ua		= LWP::UserAgent->new( agent => "RDF::Trine/$RDF::Trine::VERSION" );
	my $accept	= join(',', values %media_types);
	$ua->default_headers->push_header( 'Accept' => $accept );
	my $resp	= $ua->get( $url );
	unless ($resp->is_success) {
		warn "No content available from $url: " . $resp->status_line;
		return;
	}
	
	warn Dumper(\%media_types);
	
	my $type	= $resp->header('content-type');
	my $pclass	= $media_types{ $type };
	if ($pclass->can('new')) {
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
