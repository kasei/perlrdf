#!/usr/bin/perl
use strict;
use warnings;
use URI::file;
use Test::More tests => 50;

use Data::Dumper;
use RDF::Trine::Node;
use RDF::Trine::Namespace qw(rdf foaf);
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Iterator::Bindings;
use RDF::Trine::Iterator::Boolean;

{
	my @data	= ({ p => $rdf->type, o => $foaf->Person }, { p => $rdf->type, o => $foaf->Document });
	my $stream	= RDF::Trine::Iterator::Bindings->new( \@data, [qw(value)] );
	my $mstream	= $stream->materialize;
	my $bloom	= $mstream->bloom( 'o' );
}

