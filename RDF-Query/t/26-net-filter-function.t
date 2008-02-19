#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use FindBin qw($Bin);

use lib qw(. t);
BEGIN { require "models.pl"; }

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf Flower-2.rdf);
my (@data)	= test_models_and_classes( @files );

my $tests	= 6;
use Test::More;
plan tests => 1 + scalar(@data) * $tests;

use_ok( 'RDF::Query' );

foreach my $data (@data) {
	SKIP: {
		eval "use JavaScript 1.03;";
		skip( "Need JavaScript 1.03 or higher to run these tests.", $tests ) if ($@);
		my $model	= $data->{'modelobj'};
		my $bridge	= $data->{'bridge'};
		print "\n#################################\n";
		print "### Using model: $model\n";
		
		{
			my $sparql	= <<"END";
				PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX	dcterms: <http://purl.org/dc/terms/>
				PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
				PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
				PREFIX	func: <file://$Bin/functions.rdf#>
				SELECT	?image ?point ?name ?lat ?long
				WHERE	{
							?image rdf:type foaf:Image .
							?image dcterms:spatial ?point .
							?point foaf:name ?name .
							?point geo:lat ?lat .
							?point geo:long ?long .
							FILTER( func:distance(?lat, ?long, 41.849331, -71.392) < 10 ) .
						}
END
			my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql', net_filters => 1 );
			my $stream	= $query->execute( $model );
			my $count	= 0;
			while (my $row = $stream->()) {
				my ($image, $point, $pname, $lat, $lon)	= @{ $row };
				my $url		= $bridge->uri_value( $image );
				my $name	= $bridge->literal_value( $pname );
				like( $name, qr/, (RI|MA|CT)$/, "$name ($url)" );
				$count++;
			}
			is( $count, 3, '3 distance-based images found' );
		}
		
		{
			my $sparql	= <<"END";
				PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX	func: <file://$Bin/functions.rdf#>
				SELECT	?p
				WHERE	{
							?p a foaf:Person ;
								foaf:mbox ?mbox .
							FILTER( func:sha1(?mbox) = "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" ) .
						}
END
			my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql', net_filters => 1 );
			my ($p)		= $query->get( $model );
			my $url		= $bridge->uri_value( $p );
			is( $url, 'http://kasei.us/about/foaf.xrdf#greg', 'in-place sha1sum' );
		}

		eval "use Crypt::GPG;";
		skip( "Need Crypt::GPG to run these tests.", $tests ) if ($@);
		{
			my $sparql	= <<"END";
				PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
				PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
				PREFIX func: <file://$Bin/functions.rdf#>
				SELECT	?p
				WHERE	{
							?p a foaf:Person ;
								foaf:mbox ?mbox .
							FILTER( func:sha1(?mbox) = "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" ) .
						}
END
			my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql',
							net_filters 	=> 1,
							trusted_keys	=> ['1150 BE14 FF91 269F 398B  0F4E 0253 5AF9 A2B9 659F'],
						);
			my ($p)	= $query->get( $model );
			my $url		= $bridge->uri_value( $p );
			is( $url, 'http://kasei.us/about/foaf.xrdf#greg', 'in-place sha1sum, verified' );
		}
	}
}

