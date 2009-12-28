use Test::More tests => 3;
BEGIN { use_ok('RDF::Trine::Serializer::NTriples::Canonical') };

use strict;
use warnings;

use RDF::Trine;
use RDF::Trine::Parser;

my $data = <<"DATA";
# Hello
_:a <eg:zee> "why" . 
_:a <eg:prop> "val" .
<eg:b> <eg:prop> _:b .
_:b3 <eg:prop> "val" .
# World
DATA

my $model	= RDF::Trine::Model->new( RDF::Trine::Store->temporary_store );
my $parser	= RDF::Trine::Parser->new('turtle');
$parser->parse_into_model(undef, $data, $model);

my $serializer	= RDF::Trine::Serializer::NTriples::Canonical->new( onfail=>'space' );
my $testString	= $serializer->serialize_model_to_string($model);

my $correctString = <<"END";
<eg:b> <eg:prop> _:g1 .\r
_:g2 <eg:prop> "val" .\r
_:g2 <eg:zee> "why" .\r
\r
_:h3 <eg:prop> "val" .\r
END

is($testString, $correctString, "canonicalisation works");

{
	my ($rh, $wh);
	pipe($rh, $wh);
	$serializer->serialize_model_to_file($wh, $model);
	close($wh);
	
	local($/)	= undef;
	my $string	= <$rh>;
	is( $string, $correctString, 'serialize_model_to_file' );
}
