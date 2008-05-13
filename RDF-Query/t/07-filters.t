use strict;
use warnings;
no warnings 'redefine';
use Test::More;

use lib qw(. t);
require "models.pl";

my @files	= map { "data/$_" } qw(about.xrdf foaf.xrdf Flower-2.rdf);
my @models	= test_models( @files );
my $tests	= 0 + (scalar(@models) * 46);
plan tests => $tests;

eval "use Geo::Distance 0.09;";
my $GEO_DISTANCE_LOADED	= ($@) ? 0 : 1;

use RDF::Query;
foreach my $model (@models) {
	print "\n#################################\n";
	print "### Using model: $model\n\n";

	
	{
		print "# FILTER equality disjunction\n";
		my $sparql	= <<"END";
			PREFIX exif: <http://www.kanzaki.com/ns/exif#>
			SELECT	?image
			WHERE	{
						?image exif:exposureTime ?time .
						FILTER( ?time = "1/80" || ?time = "1/500" ) .
					}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $count	= 0;
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		while (my $row = $stream->next) {
			my $image	= $row->{image}->uri_value;
			like( $image, qr<(DSC_5705|DSC_8057)>, 'expected image URI' );
			$count++;
		}
		is( $count, 2, "3 object depictions found" );
	}

	{
		print "# FILTER REGEX\n";
		my $sparql	= <<"END";
			PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	myrdf: <http://kasei.us/e/ns/rdf#>
			PREFIX	wn: <http://xmlns.com/wordnet/1.6/>
			SELECT	?image ?thing ?type ?name
			WHERE	{
						?image foaf:depicts ?thing .
						?thing rdf:type ?type .
						?type rdfs:label ?name .
						FILTER(REGEX(STR(?type),"Flower")) .
					}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $count	= 0;
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		while (my $row = $stream->()) {
			my ($image, $thing, $ttype, $tname)	= @{ $row }{qw(image thing type name)};
			my $url		= $bridge->uri_value( $image );
			my $node	= $bridge->as_string( $thing );
			my $name	= $bridge->literal_value( $tname );
			my $type	= $bridge->as_string( $ttype );
			like( $type, qr/Flower/, "$node is a Flower" );
			$count++;
		}
		is( $count, 3, "3 object depictions found" );
	}
	
	{
		print "# FILTER isBLANK(?person)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	?person ?name
			WHERE	{
						?person a foaf:Person .
						?person foaf:name ?name .
						FILTER isBLANK(?person) .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->next) {
			isa_ok( $row, 'HASH' );
			my ($p,$n)	= @{ $row }{qw(person name)};
			isa_ok( $p, 'RDF::Trine::Node', $query->bridge->as_string( $p ) . ' is a node' );
			like( $query->bridge->literal_value( $n ), qr/^Gary|Lauren/, 'name' );
			$count++;
		}
		is( $count, 1, "1 person (bnode) found" );
	}
	
	{
		print "# FILTER isURI(?person)\n";
		my $query	= new RDF::Query ( <<"END", undef, undef, 'sparql' );
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dc: <http://purl.org/dc/elements/1.1/>
			SELECT	?person ?name
			WHERE	{
						?person a foaf:Person .
						?person foaf:name ?name .
						FILTER isURI(?person) .
					}
END
		my $stream	= $query->execute( $model );
		isa_ok( $stream, 'RDF::Trine::Iterator' );
		my $count	= 0;
		while (my $row = $stream->()) {
			isa_ok( $row, "HASH" );
			my ($p,$n)	= @{ $row }{qw(person name)};
			ok( $query->bridge->isa_node( $p ), $query->bridge->as_string( $p ) . ' is a node' );
			like( $query->bridge->literal_value( $n ), qr/^(Greg|Liz|Lauren)/, 'name' );
			$count++;
		}
		is( $count, 3, "3 people (uris) found" );
	}
	
	SKIP: {
		skip( "Need Geo::Distance 0.09 or higher to run these tests.", 4 ) unless ($GEO_DISTANCE_LOADED);
		print "# FILTER geo:distance(...)\n";
		my $sparql	= <<"END";
			PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX	mygeo: <http://kasei.us/e/ns/geo#>
			SELECT	?image ?point ?name ?lat ?long
			WHERE	{
						?image rdf:type foaf:Image .
						?image dcterms:spatial ?point .
						?point foaf:name ?name .
						?point geo:lat ?lat .
						?point geo:long ?long .
						FILTER( mygeo:distance(?point, 41.849331, -71.392) < 10 ) .
					}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		$query->add_function( 'http://kasei.us/e/ns/geo#distance', sub {
			my $query	= shift;
			my $bridge	= shift;
			my $geo		= new Geo::Distance;
			my $point	= shift;
			my $plat	= get_first_literal( $bridge, $point, 'http://www.w3.org/2003/01/geo/wgs84_pos#lat' );
			my $plon	= get_first_literal( $bridge, $point, 'http://www.w3.org/2003/01/geo/wgs84_pos#long' );
			my ($lat, $lon)	= map { Scalar::Util::blessed($_) ? $_->literal_value : $_ } @_;
			my $dist	= $geo->distance(
							'kilometer',
							$lon,
							$lat,
							$plon,
							$plat
						);
#			warn "\t-> ${dist} kilometers from Providence";
			return RDF::Query::Node::Literal->new("$dist", undef, 'http://www.w3.org/2001/XMLSchema#float');
		} );
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		while (my $row = $stream->()) {
			my ($image, $point, $pname, $lat, $lon)	= @{ $row }{qw(image point name lat long)};
			my $url		= $bridge->uri_value( $image );
			my $name	= $bridge->literal_value( $pname );
			like( $name, qr/, (RI|MA|CT)$/, "$name ($url)" );
			$count++;
		}
		is( $count, 3, "3 distance-based images found" );
	};
	
	{
		RDF::Query->add_function( 'http://kasei.us/e/ns/rdf#isa', sub {
			my $query	= shift;
			my $bridge	= shift;
			my $node	= shift;
			my $ntype	= $bridge->new_resource( shift );
			my $model	= $query->{model};
			my $p_type	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' );
			my $p_sub	= RDF::Query::Node::Resource->new( 'http://www.w3.org/2000/01/rdf-schema#subClassOf' );
			my $stmts	= $bridge->get_statements( $node, $p_type, undef );
			my %seen;
			my @types;
			while (my $s = $stmts->next) {
				push( @types, $s->object );
			}
			while (my $type = shift @types) {
				if ($type->equal( $ntype )) {
					return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				} else {
					next if ($seen{ $type->as_string }++);
					my $sub_stmts	= $bridge->get_statements( $type, $p_sub, undef );
					while (my $s = $sub_stmts->next) {
						push( @types, $s->object );
					}
				}
			}
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		} );
		
		my $sparql	= <<"END";
			PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX	rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	myrdf: <http://kasei.us/e/ns/rdf#>
			PREFIX	wn: <http://xmlns.com/wordnet/1.6/>
			SELECT	?image ?thing ?type ?name
			WHERE	{
						?image foaf:depicts ?thing .
						?thing rdf:type ?type .
						?type rdfs:label ?name .
						FILTER myrdf:isa(?thing, wn:Object) .
					}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $count	= 0;
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		while (my $row = $stream->next) {
			my ($image, $thing, $ttype, $tname)	= @{ $row }{qw(image thing type name)};
			my $url		= $bridge->uri_value( $image );
			my $node	= $bridge->as_string( $thing );
			my $name	= $bridge->literal_value( $tname );
			my $type	= $bridge->as_string( $ttype );
			ok( $name, "$node is a $name (${type} isa wn:Object)" );
			$count++;
		}
		is( $count, 3, "3 object depictions found" );
	}

	SKIP: {
		eval "require Digest::SHA1";
		if ($@) {
			skip "Digest::SHA1 required for jena:sha1sum tests", 2;
		}
		
		my $sparql	= <<"END";
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	jena: <java:com.hp.hpl.jena.query.function.library.>
			SELECT	?p
			WHERE	{
				?p foaf:mbox ?mbox .
				FILTER ( jena:sha1sum( ?mbox ) = 'f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8' ) .
			}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		
		my $count	= 0;
		my $stream	= $query->execute( $model );
		while (my $row = $stream->()) {
			my ($node)	= @{ $row }{qw(p)};
			my $uri	= $query->bridge->uri_value( $node );
			is( $uri, 'http://kasei.us/about/foaf.xrdf#greg', 'jena:sha1sum' );
			$count++;
		}
		is( $count, 1, "jena:sha1sum: 1 object found" );
	}

	{
		my $sparql	= <<"END";
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	xpath: <http://www.w3.org/2005/04/xpath-functions>
			SELECT	?p
			WHERE	{
				?p foaf:mbox ?mbox .
				FILTER ( xpath:matches(?p, "^http://kasei.us", "") ) .
			}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		
		my $count	= 0;
		my $stream	= $query->execute( $model );
		while (my $row = $stream->()) {
			my ($node)	= @{ $row }{qw(p)};
			my $uri	= $query->bridge->uri_value( $node );
			is( $uri, 'http://kasei.us/about/foaf.xrdf#greg', 'xpath:matches' );
			$count++;
		}
		is( $count, 1, "xpath:matches: 1 object found" );
	}

	SKIP: {
		local($RDF::Query::error)	= 1;
		skip( "Need Geo::Distance 0.09 or higher to run these tests.", 4 ) unless ($GEO_DISTANCE_LOADED);
		my $sparql	= <<"END";
			PREFIX	ldodds: <java:com.ldodds.sparql.>
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			SELECT	?image ?point ?name ?lat ?long
			WHERE	{
						?image a foaf:Image .
						?image dcterms:spatial ?point .
						?point foaf:name ?name .
						?point geo:lat ?lat .
						?point geo:long ?long .
						FILTER( ldodds:Distance(?lat, ?long, 41.849331, -71.392) < 10 ) .
					}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $bridge	= $query->bridge;
		my $count	= 0;
		while (my $row = $stream->next()) {
			my ($image, $point, $pname, $lat, $lon)	= @{ $row }{qw(image point name lat long)};
			my $url		= $image->uri_value;
			my $name	= $pname->literal_value;
			like( $name, qr/, (RI|MA|CT)$/, "$name ($url)" );
			$count++;
		}
		is( $count, 3, "ldodds:Distance: 3 objects found" );
	}

	{
		my $sparql	= <<"END";
			PREFIX	rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX	jfn: <java:com.hp.hpl.jena.query.function.library.>
			PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
			PREFIX	dcterms: <http://purl.org/dc/terms/>
			PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
			PREFIX test: <http://kasei.us/e/ns/test#>
			PREFIX kasei: <http://kasei.us/about/foaf.xrdf#>
			SELECT	?data
			WHERE	{
					kasei:greg test:mycollection ?col .
					?list rdf:first ?data .
					FILTER( jfn:listMember( ?col, ?data ) ) .
			}
END
		my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
		my $stream	= $query->execute( $model );
		my $count	= 0;
		my %expect	= map {$_=>1} (1..3);
		while (my $row = $stream->()) {
			my ($data)	= @{ $row }{qw(data)};
			ok( $query->bridge->isa_literal( $data ), "literal list member" );
			ok( exists($expect{ $query->bridge->literal_value( $data ) }), , "expected literal value" );
			delete $expect{ $query->bridge->literal_value( $data ) };
			$count++;
		}
		is( $count, 3, "jfn:listMember: 3 objects found" );
	}
}

######################################################################

sub get_first_literal {
	my $bridge	= shift;
	my $node	= get_first_obj( $bridge, @_ );
	return $node ? $bridge->literal_value( $node ) : undef;
}

sub get_first_obj {
	my $bridge	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : $bridge->new_resource( $_ ) } @uris;
	foreach my $pred (@preds) {
		my $stmts	= $bridge->get_statements( $node, $pred, undef );
		while (my $s = $stmts->next) {
			my $node	= $bridge->object( $s );
			return $node if ($node);
		}
	}
}
