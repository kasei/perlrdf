use 5.010;
use utf8::all;
use Test::More tests => 4;
use RDF::Trine;

my $model = RDF::Trine::Model->new;

RDF::Trine::Parser::Turtle->new->parse_file_into_model(
	'http://buzzword.org.uk/2012/rdf-trine/turtle-parsing/',
	\*DATA,
	$model,
);

$model->as_stream->each(sub
{
	my $st = shift;
	is(
		$st->object->literal_value,
		'\\',
		$st->subject->as_ntriples,
	);
});

__DATA__
<singleQuote> <output> '\\' .
<doubleQuote> <output> "\\" .
<tripleQuote> <output> '''\\''' .
<hextupleQuote> <output> """\\""" .
