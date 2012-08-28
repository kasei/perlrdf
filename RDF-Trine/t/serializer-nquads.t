use Test::More tests => 5;
BEGIN { use_ok('RDF::Trine::Serializer::NQuads') };

use strict;
use warnings;

use RDF::Trine qw(iri blank);

my $store	= RDF::Trine::Store->temporary_store();
my $model	= RDF::Trine::Model->new( $store );

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $graph1	= iri('http://example.com/graph1');
my $graph2	= blank('graph2');
my $page	= iri('http://kasei.us/');
my $g		= blank('greg');
my $st0		= RDF::Trine::Statement::Triple->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement::Triple->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement::Quad->new( $g, $foaf->homepage, $page, $graph1 );
my $st3		= RDF::Trine::Statement::Quad->new( $page, $rdf->type, $foaf->Document, $graph2 );
$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3);

{
	my ($rh, $wh);
	pipe($rh, $wh);
	my $serializer	= RDF::Trine::Serializer::NQuads->new();
	$serializer->serialize_model_to_file($wh, $model);
	close($wh);
	
	my %got;
	while (defined(my $line = <$rh>)) {
		chomp($line);
		$got{$line}++;
	}
	
	my $expect	= { map { $_ => 1 } (
		'_:greg <http://xmlns.com/foaf/0.1/homepage> <http://kasei.us/> <http://example.com/graph1> .',
		'_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .',
		'_:greg <http://xmlns.com/foaf/0.1/name> "Greg" .',
		'<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> _:graph2 .',
	) };
	
	is_deeply( \%got, $expect, 'serialize_model_to_file' );
}

{
	my $iter	= $model->get_statements( undef, $rdf->type, undef );
	
	my ($rh, $wh);
	pipe($rh, $wh);
	my $serializer	= RDF::Trine::Serializer::NQuads->new();
	$serializer->serialize_iterator_to_file($wh, $iter);
	close($wh);
	
	my %got;
	while (defined(my $line = <$rh>)) {
		chomp($line);
		$got{$line}++;
	}
	
	my $expect	= { map { $_ => 1 }
		'_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .',
		'<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .',
	};
	
	is_deeply( \%got, $expect, 'serialize_iterator_to_file with triple-based iterator' );
}

{
	my $iter	= $model->get_statements( undef, $rdf->type, undef, undef );
	
	my ($rh, $wh);
	pipe($rh, $wh);
	my $serializer	= RDF::Trine::Serializer::NQuads->new();
	$serializer->serialize_iterator_to_file($wh, $iter);
	close($wh);
	
	my %got;
	while (defined(my $line = <$rh>)) {
		chomp($line);
		$got{$line}++;
	}
	
	my $expect	= { map { $_ => 1 }
		'_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .',
		'<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> _:graph2 .',
	};
	
	is_deeply( \%got, $expect, 'serialize_iterator_to_file with quad-based iterator' );
}

{
	my $serializer	= RDF::Trine::Serializer::NQuads->new();
	my $iter		= $model->get_statements( undef, $rdf->type, undef, undef );
	my $string		= $serializer->serialize_iterator_to_string( $iter );
	my %got			= map { $_ => 1 } split(/\r?\n/, $string);
	my $expect	= { map { $_ => 1 }
		'_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .',
		'<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> _:graph2 .',
	};
	is_deeply( \%got, $expect, 'serialize_iterator_to_string with quad-based iterator' );
}
