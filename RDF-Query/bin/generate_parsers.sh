#!/bin/sh

eyapp -s -m 'RDF::Query::Parser::SPARQL' -o lib/RDF/Query/Parser/SPARQL.pm lib/RDF/Query/Parser/SPARQL.yp
eyapp -s -m 'RDF::Query::Parser::tSPARQL' -o lib/RDF/Query/Parser/tSPARQL.pm lib/RDF/Query/Parser/tSPARQL.yp
rm lib/RDF/Query/Parser/SPARQL.output
rm lib/RDF/Query/Parser/tSPARQL.output
