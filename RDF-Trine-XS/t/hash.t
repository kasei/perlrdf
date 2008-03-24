use Test::More tests => 6;

use utf8;
use_ok( 'RDF::Trine::XS' );

{
	my $value	= 'Rhttp://xmlns.com/foaf/0.1/name';
	my $hash	= RDF::Trine::XS::hash( $value );
	is( $hash, '14911999128994829034', 'URI hash' );
}

{
	my $value	= 'Lkasei<>';
	my $hash	= RDF::Trine::XS::hash( $value );
	is( $hash, '12775641923308277283', 'literal hash' );
}

{
	my $value	= 'L神崎正英<ja>';
	my $hash	= RDF::Trine::XS::hash( $value );
	is( $hash, '4303572462241715163', 'unicode literal hash' );
}

{
	my $value	= 'LTom Croucher<en>';
	my $hash	= RDF::Trine::XS::hash( $value );
	is( $hash, '14336915341960534814', 'language-typed literal hash' );
}

{
	my $value	= 'L0<>http://www.w3.org/2001/XMLSchema#integer';
	my $hash	= RDF::Trine::XS::hash( $value );
	is( $hash, '1652511136861928403', 'data-typed literal' );
}
