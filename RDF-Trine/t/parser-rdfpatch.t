use Test::More;
use Test::Exception;
use strict;
use warnings;

use RDF::Trine qw(iri blank literal);
use RDF::Trine::Parser;
use RDF::Trine::Parser::RDFPatch;

my $parser	= RDF::Trine::Parser::RDFPatch->new();
isa_ok( $parser, 'RDF::Trine::Parser::RDFPatch' );

my $model	= RDF::Trine::Model->new();

{
	throws_ok {
		$parser->parse_line( 'X 1 .' );
	} 'RDF::Trine::Error::ParserError', 'Bad RDF Patch operation ID threw RDF::Trine::Error::ParserError';
	like( $@, qr/Unknown/, 'Good exception description' );
}

{
	throws_ok {
		$parser->parse_line( 'A 1 .' );
	} 'RDF::Trine::Error::ParserError', 'Bad RDF Patch operation arity threw RDF::Trine::Error::ParserError';
	like( $@, qr/arity/, 'Good exception description' );
}

{
	my $op	= $parser->parse_line( "A _:a a 3 ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'A', 'Expected RDF Patch operation ID');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement');
	
	is($model->size, 0, 'Expected empty test model');
	$op->execute($model);
	is($model->size, 1, 'Expected 1-statement test model');
}

{
	my $op	= $parser->parse_line( "D _:a a 3 ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'D', 'Expected RDF Patch operation ID');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement');

	$op->execute($model);
	is($model->size, 0, 'Expected empty test model');
}

{
	my $op	= $parser->parse_line( "D _:a a 3 _:g ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'D', 'Expected RDF Patch operation ID');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement::Quad');

	$op->execute($model);
	is($model->size, 0, 'Expected empty test model');
}

{
	$parser->parse_line( "A <s> <p> 1 ." )->execute($model);
	$parser->parse_line( "A <s> <p> 2 ." )->execute($model);
	$parser->parse_line( "A <q> <r> 3 ." )->execute($model);
	
	my $op	= $parser->parse_line( "Q U <p> U ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'Q', 'Expected RDF Patch operation ID');
	
	my $iter	= $op->execute($model);
	isa_ok($iter, 'RDF::Trine::Iterator' );
	
	my $count	= 0;
	while (my $st = $iter->next) {
		$count++;
		is($st->subject->value, 's', 'expected subject');
		like($st->object->value, qr/^[12]$/, 'expected object');
	}
	is($count, 2, 'expected result count');
}

{
	my $parser	= RDF::Trine::Parser::RDFPatch->new();
	$parser->parse_line( '@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .' );
	my $op	= $parser->parse_line( "A _:a rdf:type 3 ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'A', 'Expected RDF Patch operation ID');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement');
	is( $st->predicate->value, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'expected IRI from PrefixName' );
}

done_testing();
