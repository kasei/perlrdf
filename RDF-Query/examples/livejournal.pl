#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use lib qw(../lib);

use RDF::Query;
use Data::Dumper;

my $nick	= scalar(@ARGV) ? shift : do { print "Nickname: "; my $n = <STDIN>; chomp($n); $n };

my $url		= "http://${nick}.livejournal.com/data/foaf.rdf";
my $sparql	= <<"END";
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?nick
FROM <${url}>
WHERE {
	?person foaf:nick "${nick}"\@en ;
		foaf:knows ?friend .
	?friend foaf:nick ?nick .
}
ORDER BY ?nick
END

my $query	= RDF::Query->new( $sparql, undef, undef, 'sparql' );
warn RDF::Query->error unless ($query);

my $stream	= $query->execute;
while (my $row = $stream->()) {
	my $friend	= $row->{nick};
	if ($friend->is_literal) {
		my $name	= $friend->literal_value;
		print "$nick knows $name\n";
	}
}




# ### If we wanted to see the RDF that was loaded from the URL
# ### before the query is executed, we could add a 
# ### post-creatae-model hook function like this:
#
# RDF::Query->add_hook(
# 	'http://kasei.us/code/rdf-query/hooks/post-create-model',
# 	sub {
# 		my $query	= shift;
# 		my $bridge	= shift;
# 		my $stream	= $bridge->get_statements();
# 		while (my $st = $stream->()) {
# 			warn 'added statement: ' . $bridge->as_string( $st ) . "\n";
# 		}
# 	}
# );

