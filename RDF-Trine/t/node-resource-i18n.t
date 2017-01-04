#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 2;

use utf8;

use RDF::Trine;
use RDF::Trine::Node;

{
	my $uri	= RDF::Trine::Node::Resource->new('http://kasei.us/#火星');
	is( $uri->uri_value, 'http://kasei.us/#火星', 'i18n uri value' );
}

{
	my $base	= RDF::Trine::Node::Resource->new('http://kasei.us/');
	my $uri		= RDF::Trine::Node::Resource->new('#火星', $base);
	is( $uri->uri_value, 'http://kasei.us/#火星', 'i18n uri value using BASE' );
}

__END__
