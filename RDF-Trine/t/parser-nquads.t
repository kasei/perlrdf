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

################################################################################
Log::Log4perl::init( \q[
	log4perl.category.rdf.trine.model          = TRACE, Screen
	
	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
	log4perl.appender.Screen.stderr  = 0
	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
] );
################################################################################

my $parser	= RDF::Trine::Parser->new( 'nquads' );
isa_ok( $parser, 'RDF::Trine::Parser::NQuads' );

{
	my $model = RDF::Trine::Model->temporary_model;
	my $nquads	= <<"END";
	_:a <b> <a> .
	_:a <b> <a> <g1> .
	<a> <b> _:a <g2> .
END
	$parser->parse_into_model(undef, $nquads, $model);
	
	is( $model->size, 2, 'expected model (triple) size after nquads parse' );
	is( $model->count_statements(undef, undef, undef, undef), 3, 'expected 3 count ffff' );
	is( $model->count_statements(blank('a'), undef, undef, undef), 2, 'expected 2 count bfff' );
	is( $model->count_statements(iri('a')), 1, 'expected 1 count bff' );
	is( $model->count_statements(iri('a'), undef, undef, undef), 1, 'expected 1 count bfff' );
	is( $model->count_statements(iri('b')), 0, 'expected 0 count bff' );
	is( $model->count_statements(iri('b'), undef, undef, undef), 0, 'expected 0 count bfff' );
	is( $model->count_statements(undef, iri('b')), 2, 'expected 2 count fbf' );
	is( $model->count_statements(undef, iri('b'), undef, undef), 3, 'expected 3 count fbff' );
	is( $model->count_statements(undef, undef, undef, iri('g1')), 1, 'expected 1 count fffb' );
}
