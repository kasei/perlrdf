use Test::More tests => 10;
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

my $parser	= RDF::Trine::Parser->new( 'ntriples' );
isa_ok( $parser, 'RDF::Trine::Parser::NTriples' );

{
	my $model = RDF::Trine::Model->temporary_model;
	my $ntriples	= <<"END";
<a> <a> <a> .
<a> <b> <c> .
<a> <b> _:a .
<a> <d> "D" .
<c> <b> <a> .
END
	$parser->parse_into_model(undef, $ntriples, $model);
	my $iter	= $model->bounded_description( iri('a') );
	isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
	my @st	= $iter->get_all;
	is( scalar(@st), 5, 'expected triple count' );
	my @expect	= (
		'(triple <a> <a> <a>)',
		'(triple <a> <b> <c>)',
		'(triple <a> <b> _:a)',
		'(triple <a> <d> "D")',
		'(triple <c> <b> <a>)',
	);
	my @seen	= sort map { $_->as_string } @st;
	is_deeply( \@seen, \@expect, 'BD with 0-outdegree bnode' );
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $ntriples	= <<"END";
<a> <a> <a> .
<a> <b> <c> .
<a> <b> _:a .
_:a <c> "C" .
END
	$parser->parse_into_model(undef, $ntriples, $model);
	my $iter	= $model->bounded_description( iri('a') );
	isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
	my @st	= $iter->get_all;
	is( scalar(@st), 4, 'expected triple count' );
	my @expect	= (
		'(triple <a> <a> <a>)',
		'(triple <a> <b> <c>)',
		'(triple <a> <b> _:a)',
		'(triple _:a <c> "C")'
	);
	my @seen	= sort map { $_->as_string } @st;
	is_deeply( \@seen, \@expect, 'BD with 1-outdegree bnode' );
}

{
	my $model = RDF::Trine::Model->temporary_model;
	my $ntriples	= <<"END";
<a> <a> <a> .
<a> <b> <c> .
<a> <b> _:a .
_:a <c> _:c .
_:c <d> "D" .
END
	$parser->parse_into_model(undef, $ntriples, $model);
	my $iter	= $model->bounded_description( iri('a') );
	isa_ok( $iter, 'RDF::Trine::Iterator::Graph' );
	my @st	= $iter->get_all;
	is( scalar(@st), 5, 'expected triple count' );
	my @expect	= (
		'(triple <a> <a> <a>)',
		'(triple <a> <b> <c>)',
		'(triple <a> <b> _:a)',
		'(triple _:a <c> _:c)',
		'(triple _:c <d> "D")'
	);
	my @seen	= sort map { $_->as_string } @st;
	is_deeply( \@seen, \@expect, 'BD with 1-outdegree bnode chain' );
}
