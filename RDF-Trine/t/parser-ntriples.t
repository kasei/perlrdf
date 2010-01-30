use Test::More tests => 11;
use Test::Exception;
use FindBin qw($Bin);
use File::Spec;
use Data::Dumper;
use utf8;
binmode( \*STDOUT, ':utf8' );
binmode( \*STDERR, ':utf8' );

use RDF::Trine qw(iri blank literal);
use RDF::Trine::Parser;

my $parser	= RDF::Trine::Parser->new( 'ntriples' );
isa_ok( $parser, 'RDF::Trine::Parser::NTriples' );

{
	my $model = RDF::Trine::Model->temporary_model;
	my $ntriples	= <<"END";
	_:a <b> <a> .
	<a> <b> _:a .
END
	$parser->parse_into_model(undef, $ntriples, $model);
	
	is( $model->size, 2, 'expected model size after ntriples parse' );
	is( $model->count_statements(blank('a')), 1, 'expected 1 count bff' );
	is( $model->count_statements(iri('a')), 1, 'expected 1 count bff' );
	is( $model->count_statements(iri('b')), 0, 'expected 0 count bff' );
	is( $model->count_statements(undef, iri('b')), 2, 'expected 2 count fbf' );
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $ntriples	= qq[_:eve <http://example.com/resum\\u00E9> <http://example.com/resume.html> .\n];
	$parser->parse_into_model(undef, $ntriples, $model);
	is( $model->size, 1, 'expected model size after ntriples parse' );
	is( $model->count_statements(undef, iri('http://example.com/resumé')), 1, 'expected 1 count fbf with unicode escaping' );
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $ntriples	= qq[_:eve <http://example.com/resum\\u00E9> "Resume" .\n];
	$parser->parse_into_model(undef, $ntriples, $model);
	is( $model->size, 1, 'expected model size after ntriples parse' );
	is( $model->count_statements(undef, undef, literal('Resume')), 1, 'expected 1 count fbf with unicode escaping' );
}

{
	my %got;
	my $handler	= sub {
		my $st	= shift;
		my $o	= $st->object;
		$got{ $o->as_string }++
	};
	my $ntriples	= <<"END";
_:anon <http://example.org/property> <http://example.org/resource2> .
<http://example.org/resource14> <http://example.org/property> "x" .
<http://example.org/resource16> <http://example.org/property> "\\u00E9" .
<http://example.org/resource21> <http://example.org/property> "<p/>"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral> .
<http://example.org/resource30> <http://example.org/property> "chat"\@fr .
END
	$parser->parse(undef, $ntriples, $handler);
	my %expect	= (
		q["é"]	=> 1,
		q["chat"@fr]	=> 1,
		q["x"]	=> 1,
		q["<p/>"^^<http://www.w3.org/2000/01/rdf-schema#XMLLiteral>]	=> 1,
		q[<http://example.org/resource2>]	=> 1,
	);
	is_deeply( \%got, \%expect, 'expected statement object parsing' );
}
