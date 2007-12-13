#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);

use File::Spec;
use RDF::Query;
use RDF::Redland;

unless (@ARGV == 1) {
	print <<"END";
USAGE:\t$0 data.rdf

END
	exit;
}

my $file		= shift(@ARGV);
my $model		= new_model( $file );
my $base_uri	= RDF::Redland::URI->new('http://kasei.us/e/ns/base/');
#my $serializer	= RDF::Redland::Serializer->new("turtle");
#print $serializer->serialize_model_to_string($base_uri, $model);

my $query;
if (1) {
	$query		= RDF::Query->new( <<"END", undef, undef, 'tsparql' );
	PREFIX t: <http://www.w3.org/2006/09/time#>
	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
	SELECT ?name WHERE {
		?p a foaf:Person .
#		TIME [ t:begins "2000-01-01" ] { ?p foaf:name ?name . }
		TIME [ t:ends "1999-12-31" ] { ?p foaf:name ?name . }
	}
END
} else {
# 	$query		= RDF::Query->new( <<"END", undef, undef, 'tsparql' );
# 	PREFIX t: <http://www.w3.org/2006/09/time#>
# 	PREFIX foaf: <http://xmlns.com/foaf/0.1/>
# 	SELECT ?name WHERE {
# 		?p a foaf:Person .
# 		GRAPH ?t { ?p foaf:name ?name . }
# 		?t t:begins "2000-01-01" .
# 	}
# END
}

warn RDF::Query->error unless ($query);
my $stream		= $query->execute( $model );
while (my $d = $stream->()) {
	my @d	= @$d;
	warn join("\t", map { $_->as_string } @d);
}



sub new_model {
	my $file		= shift;
	my $base_uri	= RDF::Redland::URI->new('http://kasei.us/e/ns/base/');
	my $storage		= RDF::Redland::Storage->new("hashes", "test", "new='yes',hash-type='memory',contexts='yes'");
	my $model		= RDF::Redland::Model->new($storage, "");
	
	my $source_uri	= RDF::Redland::URI->new('file://' . File::Spec->rel2abs($file));
	my $parser		= RDF::Redland::Parser->new("guess");
	
	$parser->parse_into_model($source_uri, $base_uri, $model);
	
	my @conditions;
	{
		my $cond		= RDF::Redland::Node->new_from_uri('http://purl.org/vocab/bio/0.1/condition');
		my $pattern		= RDF::Redland::Statement->new( undef, $cond, undef );
		my $stream		= $model->find_statements( $pattern );
		while ($stream and not $stream->end) {
			my $statement	= $stream->current;
			my $person		= $statement->subject;
			my $condition	= $statement->object;
			push(@conditions, [$person, $condition]);
			$stream->next;
		}
	}
	
	my $p_type		= RDF::Redland::Node->new_from_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
	my $time_re		= qr[^http://www.w3.org/2006/09/time#];
	foreach my $data (@conditions) {
		my ($person, $condition)	= @$data;
		
		my @statements;
		my $pattern		= RDF::Redland::Statement->new( $condition, undef, undef );
		my $stream		= $model->find_statements( $pattern );
		
		my $interval	= new_interval( $model );
		while ($stream and not $stream->end) {
			my $statement	= $stream->current;
			my $pred		= $statement->predicate;
			my $obj			= $statement->object;
			next if ($pred->equals($p_type));
			
			if ($pred->uri->as_string =~ $time_re) {
				my $uri		= $pred->uri->as_string;
				my ($prop)	= $uri =~ m/${time_re}(.*)$/;
				add_interval_property( $model, $interval, $prop => $obj );
			} else {
				my $obj			= $statement->object;
				my $cond_st		= RDF::Redland::Statement->new($person, $pred, $obj);
				push(@statements, $cond_st);
			}
		} continue {
			$stream->next;
		}
		
		foreach my $st (@statements) {
			$model->add_statement( $st, $interval );
		}
	}
	return $model;
}	


sub add_interval_property {
	my $model	= shift;
	my $int		= shift;
	my %args	= @_;
	
	if ($args{begins}) {
		my $begins	= $args{begins};
		my $p		= RDF::Redland::Node->new_from_uri('http://www.w3.org/2006/09/time#begins');
		my $st		= RDF::Redland::Statement->new( $int, $p, $begins );
		$model->add_statement( $st );
	}

	if ($args{inside}) {
		my $inside	= $args{inside};
		my $p		= RDF::Redland::Node->new_from_uri('http://www.w3.org/2006/09/time#inside');
		my $st		= RDF::Redland::Statement->new( $int, $p, $inside );
		$model->add_statement( $st );
	}

	if ($args{ends}) {
		my $ends	= $args{ends};
		my $p		= RDF::Redland::Node->new_from_uri('http://www.w3.org/2006/09/time#ends');
		my $st		= RDF::Redland::Statement->new( $int, $p, $ends );
		$model->add_statement( $st );
	}
}

sub new_interval {
	my $model	= shift;
	my %args	= @_;
	
	my $int			= RDF::Redland::Node->new();
	
	my $type		= RDF::Redland::Node->new('http://www.w3.org/2000/01/rdf-schema#type');
	my $interval	= RDF::Redland::Node->new('http://www.w3.org/2006/09/time#Interval');
	my $st			= RDF::Redland::Statement->new( $int, $type, $interval );
	$model->add_statement( $st );
	
	return $int;
}






