#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Test::More qw(no_plan);
use Test::Exception;

use_ok( 'RDF::Base::Namespace' );


my $foaf	= RDF::Base::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
my $uri		= $foaf->homepage;

isa_ok( $uri, 'RDF::Base::Node::Resource' );
is( $uri->uri_value, 'http://xmlns.com/foaf/0.1/homepage', 'got expected URI value for foaf:homepage' );

