use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Trine qw(iri);

my $data	= <<'END';
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://dbpedia.org/class/yago/StatesOfGermany> .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "\u30D9\u30EB\u30EA\u30F3"@ja .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "\u67CF\u6797"@zh .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlino"@it .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlin"@de .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlim"@pt .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlin"@fr .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlin"@en .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berl\u00EDn"@es .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlin"@pl .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlin"@sv .
<http://dbpedia.org/resource/Berlin> <http://www.w3.org/2000/01/rdf-schema#label> "Berlijn"@nl .
END

my $parser	= RDF::Trine::Parser->new('ntriples');
my $store	= RDF::Trine::Store::Memory->new();
my $model	= RDF::Trine::Model->new($store);
$parser->parse_into_model("http://dbpedia.org/resource/Berlin", $data, $model);

is($model->size, 12, 'expected model size');

{
	my $lstore	= RDF::Trine::Store::LanguagePreference->new( $store, {} );
	my $lmodel	= RDF::Trine::Model->new($lstore);
	is($lmodel->size, 2, 'expected language model size');
	my $iter	= $lstore->get_statements(undef, iri('http://www.w3.org/2000/01/rdf-schema#label'), undef);
	my $count	= 0;
	while (my $st = $iter->next) {
		my $o	= $st->object;
		is($o->literal_value_language, 'en', 'Accept-Language: ');
		$count++;
	}
	is($count, 1, 'expected count');
}

{
	my $lstore	= RDF::Trine::Store::LanguagePreference->new( $store, { 'en' => 1.0 } );
	my $lmodel	= RDF::Trine::Model->new($lstore);
	my $iter	= $lstore->get_statements(undef, iri('http://www.w3.org/2000/01/rdf-schema#label'), undef);
	my $count	= 0;
	while (my $st = $iter->next) {
		my $o	= $st->object;
		is($o->literal_value_language, 'en', 'Accept-Language: en;q=1.0');
		$count++;
	}
	is($count, 1, 'expected count');
}

{
	my $lstore	= RDF::Trine::Store::LanguagePreference->new( $store, { 'en' => 0.9, 'ja' => 1.0 } );
	my $lmodel	= RDF::Trine::Model->new($lstore);
	my $iter	= $lstore->get_statements(undef, iri('http://www.w3.org/2000/01/rdf-schema#label'), undef);
	my $count	= 0;
	while (my $st = $iter->next) {
		my $o	= $st->object;
		is($o->literal_value_language, 'ja', 'Accept-Language: en;q=0.9, ja;q=1.0');
		$count++;
	}
	is($count, 1, 'expected count');
}

done_testing();
