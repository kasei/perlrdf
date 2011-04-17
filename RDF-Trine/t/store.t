use Test::More tests => 3;

# This file now only contains tests that are relevant to all stores

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri variable store literal);
use RDF::Trine::Store;

use FindBin '$Bin';
use lib "$Bin/lib";


isa_ok( store( 'Memory' ), 'RDF::Trine::Store::Memory' );
isa_ok( RDF::Trine::Store->new_with_string( 'Memory' ), 'RDF::Trine::Store::Memory' );
isa_ok( RDF::Trine::Store->new_with_string( 'SPARQL;http://example/' ), 'RDF::Trine::Store::SPARQL' );

