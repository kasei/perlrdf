use Test::More tests => 5;

use strict;
use warnings;
no warnings 'redefine';
use RDF::Trine qw(iri variable statement);

use RDF::Trine;
use_ok('RDF::Trine::Exporter::CSV');

{
	my $e	= RDF::Trine::Exporter::CSV->new();
	isa_ok( $e, 'RDF::Trine::Exporter::CSV' );
}

my $model = RDF::Trine::Model->temporary_model;
$model->add_hashref({
	'http://example.com/doc' => {
		'http://example.com/predicate' => [
				{
					'type' => 'literal',
					'value' => 'Foo',
				},
				{
					'type' => 'uri',
					'value' => 'http://example.com/bar',
				},
				'baz@en'
			],
		},
	});



{
	my $e	= RDF::Trine::Exporter::CSV->new( quote => 1 );
	my $t		= statement( iri('http://example.com/doc'), variable('p'), variable('o') );
	my $iter	= $model->get_pattern( $t, undef, orderby => [ qw(p ASC o ASC) ] );
	my ($rh, $wh);
	pipe( $rh, $wh );
	$e->serialize_iterator_to_file( $wh, $iter );
	close($wh);
	my $got		= do { local($/) = undef; <$rh> };
	my $expect	= <<'END';
p,o
<http://example.com/predicate>,<http://example.com/bar>
<http://example.com/predicate>,"""Foo"""
<http://example.com/predicate>,"""baz""@en"
END
	is( $got, $expect, 'quote=1' );
}

{
	my $e	= RDF::Trine::Exporter::CSV->new( quote => 0 );
	my $t		= statement( iri('http://example.com/doc'), variable('p'), variable('o') );
	my $iter	= $model->get_pattern( $t, undef, orderby => [ qw(p ASC o ASC) ] );
	my ($rh, $wh);
	pipe( $rh, $wh );
	$e->serialize_iterator_to_file( $wh, $iter );
	close($wh);
	my $got		= do { local($/) = undef; <$rh> };
	my $expect	= <<'END';
p,o
http://example.com/predicate,http://example.com/bar
http://example.com/predicate,Foo
http://example.com/predicate,baz
END
	is( $got, $expect, 'quote=0' );
}

{
	my $e	= RDF::Trine::Exporter::CSV->new( quote => 0, sep_char => '|' );
	my $t		= statement( iri('http://example.com/doc'), variable('p'), variable('o') );
	my $iter	= $model->get_pattern( $t, undef, orderby => [ qw(p ASC o ASC) ] );
	my ($rh, $wh);
	pipe( $rh, $wh );
	$e->serialize_iterator_to_file( $wh, $iter );
	close($wh);
	my $got		= do { local($/) = undef; <$rh> };
	my $expect	= <<'END';
p|o
http://example.com/predicate|http://example.com/bar
http://example.com/predicate|Foo
http://example.com/predicate|baz
END
	is( $got, $expect, 'sep_char=|' );
}
