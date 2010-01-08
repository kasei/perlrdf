use Test::More tests => 207;
use Test::Exception;

use utf8;
use strict;
use warnings;
no warnings 'redefine';

use DBI;
use RDF::Trine qw(iri);
use RDF::Trine::Model;

### Test a temporary model's ability to switch from a fast in-memory store
### (::Store::Hexastore) initially to a more scalable store (::Store::DBI)
### as more triples are loaded.

my $model	= RDF::Trine::Model->temporary_model;
isa_ok( $model, 'RDF::Trine::Model' );
isa_ok( $model->_store, 'RDF::Trine::Store::Hexastore', 'expected initial store type' );

is( $model->size, 0, 'expected model size' );
$model->{threshold}	= 10;
foreach my $i (0 .. $model->{threshold}) {
	my $n	= iri("http://example.org/$i");
	my $st	= RDF::Trine::Statement->new( $n, $n, $n );
	$model->add_statement( $st );
}
is( $model->size, 11, 'expected model size' );
isa_ok( $model->_store, 'RDF::Trine::Store::DBI', 'expected store type beyond threshold' );
