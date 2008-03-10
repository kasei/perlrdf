#!/usr/bin/perl
use strict;
use Test::More;
use Test::Exception;

use RDF::Query;

if (RDF::Query->loadable_bridge_class) {
	plan( tests => 3 );
} else {
	plan( skip_all => "Cannot find a loadable RDF model class." );
	return;
}

SKIP: {
	eval { require LWP::Simple };
	skip "LWP::Simple is not available", 3 if $@;
	
	my $query	= RDF::Query->new(<<"END", undef, undef, 'sparql');
		PREFIX	foaf: <http://xmlns.com/foaf/0.1/>
		PREFIX	geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
		SELECT	?lat ?long
		FROM	<http://homepage.mac.com/samofool/rdf-query/test-data/greenwich.rdf>
		WHERE	{
					?point a geo:Point ;
						geo:lat ?lat ;
						geo:long ?long .
				}
END
	$query->add_hook( 'http://kasei.us/code/rdf-query/hooks/post-create-model', sub {
		my $self	= shift;
		my $bridge	= shift;
		my $model	= $bridge->model;
		
		my $long	= $bridge->new_resource('http://www.w3.org/2003/01/geo/wgs84_pos#long');
#		my $st		= $bridge->new_statement( undef, $long, undef );
		my $stream	= $bridge->get_statements( undef, $long, undef );
#		my @stmts	= $model->find_statements( $st );
#		foreach my $stmt (@stmts) {
		while (my $stmt = $stream->next) {
			my $l	= $bridge->literal_value( $bridge->object( $stmt ) );
			my $dt	= $bridge->literal_datatype( $bridge->object( $stmt ) );
			$l		= sprintf( '%0.6f', ++$l );
			$bridge->remove_statement( $stmt );

			my $lit	= $bridge->new_literal( $l, undef, $dt );
			my $add	= $bridge->new_statement( $bridge->subject($stmt), $bridge->predicate($stmt), $lit );
			$bridge->add_statement( $add );
		}
	} );

	my $count	= 0;
	my $stream	= $query->execute();
	my $bridge	= $query->bridge;
	while (my $row = $stream->next) {
		my ($lat, $long)	= @{ $row }{qw(lat long)};
		is( $bridge->literal_value( $lat ), '51.477222', 'existing latitude' );
		is( $bridge->literal_value( $long ), '1.000000', 'modified longitude' );
	} continue { ++$count };
	is( $count, 1, 'expecting one statement in model' );
}



__END__
