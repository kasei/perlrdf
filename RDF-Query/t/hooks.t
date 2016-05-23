#!/usr/bin/env perl
use strict;
use Test::More;
use Test::Exception;

use RDF::Query;

if ($ENV{RDFQUERY_NETWORK_TESTS}) {
	plan( tests => 3 );
} else {
	plan skip_all => 'No network. Set RDFQUERY_NETWORK_TESTS to run these tests.';
	return;
}

SKIP: {
	eval { require LWP::Simple };
	skip "LWP::Simple is not available", 3 if $@;
	
	my $query	= RDF::Query->new(<<"END", undef, undef, 'sparql');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
		SELECT	?lat ?long
		FROM	<http://kasei.us/code/rdf-query/test-data/greenwich.rdf>
		WHERE	{
					?point a geo:Point ;
						geo:lat ?lat ;
						geo:long ?long .
				}
END
	$query->add_hook( 'http://kasei.us/code/rdf-query/hooks/post-create-model', sub {
		my $self	= shift;
		my $model	= shift;
		
		my $long	= RDF::Trine::Node::Resource->new( 'http://www.w3.org/2003/01/geo/wgs84_pos#long' );
		my $stream	= $model->get_statements( undef, $long, undef );
		while (my $stmt = $stream->next) {
			my $l	= $stmt->object->literal_value;
			my $dt	= $stmt->object->literal_datatype;
			$l		= sprintf( '%0.6f', ++$l );
			$model->remove_statement( $stmt );

			my $lit	= RDF::Trine::Node::Literal->new( $l, undef, $dt );
			my $add	= RDF::Trine::Statement->new( $stmt->subject, $stmt->predicate, $lit );
			$model->add_statement( $add );
		}
	} );

	my $count	= 0;
	my $stream	= $query->execute();
	while (my $row = $stream->next) {
		my ($lat, $long)	= @{ $row }{qw(lat long)};
		is( $lat->literal_value, '51.477222', 'existing latitude' );
		is( $long->literal_value, '1.000000', 'modified longitude' );
	} continue { ++$count };
	is( $count, 1, 'expecting one statement in model' );
}



__END__
