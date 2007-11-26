#!/usr/bin/perl

use strict;
use warnings;

use URI;
use Data::Dumper;
use Test::More tests => 48; # qw(no_plan);
use Test::Exception;
use Scalar::Util qw(blessed reftype);

use_ok( 'RDF::Base::Storage::DBI' );

my $dbi	= RDF::Base::Storage::DBI->new();
isa_ok( $dbi, 'RDF::Base::Storage::DBI' );

sub parse_triple ($);



my $data	= <<'END';
(r1) [http://www.w3.org/1999/02/22-rdf-syntax-ns#type] [http://xmlns.com/foaf/0.1/Person]
(r1) [http://xmlns.com/foaf/0.1/name] "Gregory Williams"
(r1) [http://xmlns.com/foaf/0.1/homepage] [http://kasei.us/]
(r1) [http://xmlns.com/foaf/0.1/nick] "kasei"

(r2) [http://www.w3.org/1999/02/22-rdf-syntax-ns#type] [http://xmlns.com/foaf/0.1/Person]
(r2) [http://xmlns.com/foaf/0.1/nick] "ubu"

(r3) [http://www.w3.org/1999/02/22-rdf-syntax-ns#type] [http://xmlns.com/foaf/0.1/Person]
(r3) [http://xmlns.com/foaf/0.1/nick] "aaaa"

END

foreach my $string (split(/\n/, $data)) {
	next unless ($string);
	$dbi->add_statement( parse_triple $string );
}

my $type	= parse_triple qq[	?person [http://www.w3.org/1999/02/22-rdf-syntax-ns#type] ?type	];
my $name	= parse_triple qq[	?person [http://xmlns.com/foaf/0.1/nick] ?nick	];

{
	my $stream	= $dbi->multi_get( triples => [ $type ] );
	my $data	= $stream->next();
	is( reftype($data), 'HASH', 'stream data returned' );
	
	my ($person, $type)	= @{ $data }{qw(person type)};
	isa_ok( $person, 'RDF::Query::Node::Blank' );
	like( $person->blank_identifier, qr/^r\d+$/, 'valid blank node id' );
	
	isa_ok( $type, 'RDF::Query::Node::Resource' );
	is( $type->uri_value, 'http://xmlns.com/foaf/0.1/Person', 'type is foaf:Person' );
}

{
	my $stream	= $dbi->multi_get( triples => [ $type, $name ] );
	while (my $data = $stream->next) {
		is( reftype($data), 'HASH', 'stream data returned' );
		
		my ($person, $nick, $type)	= @{ $data }{qw(person nick type)};
		isa_ok( $person, 'RDF::Query::Node::Blank' );
		like( $person->blank_identifier, qr/^r\d+$/, 'valid blank node id' );
		
		isa_ok( $nick, 'RDF::Query::Node::Literal' );
		like( $nick->literal_value, qr/^(kasei|ubu|aaaa)$/, 'known foaf:nick' );
		
		isa_ok( $type, 'RDF::Query::Node::Resource' );
		is( $type->uri_value, 'http://xmlns.com/foaf/0.1/Person', 'type is foaf:Person' );
	}
}

{
	my $last;
	my $stream	= $dbi->multi_get( triples => [ $type, $name ], order => 'nick' );
	while (my $data = $stream->next) {
		is( reftype($data), 'HASH', 'stream data returned' );
		
		my ($person, $nick, $type)	= @{ $data }{qw(person nick type)};
		isa_ok( $person, 'RDF::Query::Node::Blank' );
		like( $person->blank_identifier, qr/^r\d+$/, 'valid blank node id' );
		
		isa_ok( $nick, 'RDF::Query::Node::Literal' );
		if (defined($last)) {
			cmp_ok( $nick->literal_value, 'ge', $last, 'order by ?nick' );
		} else {
			$last	= $nick->literal_value;
		}
		
		isa_ok( $type, 'RDF::Query::Node::Resource' );
		is( $type->uri_value, 'http://xmlns.com/foaf/0.1/Person', 'type is foaf:Person' );
	}
}


exit;


sub parse_triple ($) {
	my $string	= shift;
	my @nodes;
	
	my @pos	= qw(subject predicate object);
	while ($string =~ /\S/) {
		$string		=~ s/^\s+//;
		my $type	= substr($string,0,1,'');
		my $pos		= shift(@pos);
		if ($type eq '"') {
			my $index	= index($string, '"');
			my $value	= substr($string, 0, $index, '');
			substr($string,0,1,'');
			push(@nodes, $pos => RDF::Query::Node::Literal->new( value => $value ));
		} elsif ($type eq '[') {
			my $index	= index($string, ']');
			my $value	= substr($string, 0, $index, '');
			substr($string,0,1,'');
			push(@nodes, $pos => RDF::Query::Node::Resource->new( uri => $value ));
		} elsif ($type eq '(') {
			my $index	= index($string, ')');
			my $value	= substr($string, 0, $index, '');
			substr($string,0,1,'');
			push(@nodes, $pos => RDF::Query::Node::Blank->new( name => $value ));
		} elsif ($type eq '?') {
			my ($value)	= ($string =~ m#^(\w+)#);
			substr($string, 0, length($value), '');
			push(@nodes, $pos => RDF::Query::Node::Variable->new( name => $value ));
		} else {
			warn "Unknown node type ${type}";
		}
	}
	
	my $st	= RDF::Base::Statement->new( @nodes );
	return $st;
}
