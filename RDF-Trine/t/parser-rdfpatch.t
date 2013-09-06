use Test::More;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;
use Data::Dumper;
use utf8;
use strict;
use warnings;
binmode( \*STDOUT, ':utf8' );
binmode( \*STDERR, ':utf8' );

use RDF::Trine qw(iri blank literal);
use RDF::Trine::Parser;
use RDF::Trine::Parser::RDFPatch;

my $parser	= RDF::Trine::Parser::RDFPatch->new();
isa_ok( $parser, 'RDF::Trine::Parser::RDFPatch' );

my $model	= RDF::Trine::Model->new();

{
	my $op	= $parser->parse_line( "A _:a a 3 ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'A');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement');
	
	is($model->size, 0);
	$op->execute($model);
	is($model->size, 1);
}

{
	my $op	= $parser->parse_line( "D _:a a 3 ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'D');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement');

	$op->execute($model);
	is($model->size, 0);
}

{
	my $op	= $parser->parse_line( "D _:a a 3 _:g ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'D');
	my ($st)	= $op->args;
	isa_ok($st, 'RDF::Trine::Statement::Quad');

	$op->execute($model);
	is($model->size, 0);
}

{
	$parser->parse_line( "A <s> <p> 1 ." )->execute($model);
	$parser->parse_line( "A <s> <p> 2 ." )->execute($model);
	$parser->parse_line( "A <q> <r> 3 ." )->execute($model);
	
	my $op	= $parser->parse_line( "Q U <p> U ." );
	isa_ok($op, 'RDF::Trine::Parser::RDFPatch::Op' );
	is($op->op, 'Q');
	
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

done_testing();
