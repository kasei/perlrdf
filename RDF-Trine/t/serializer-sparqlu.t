use Test::More tests => 7;
BEGIN { use_ok('RDF::Trine::Serializer::SparqlUpdate') };

use strict;
use warnings;
use Data::Dumper;

use RDF::Trine;
use RDF::Trine::Parser;

my $store	= RDF::Trine::Store->temporary_store();
my $model	= RDF::Trine::Model->new( $store );

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');

my $page	= RDF::Trine::Node::Resource->new('http://kasei.us/');
my $g		= RDF::Trine::Node::Blank->new('greg');
my $st0		= RDF::Trine::Statement->new( $g, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $g, $foaf->name, RDF::Trine::Node::Literal->new('Greg') );
my $st2		= RDF::Trine::Statement->new( $g, $foaf->homepage, $page );
my $st3		= RDF::Trine::Statement->new( $page, $rdf->type, $foaf->Document );
$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3);

{
	my ($rh, $wh);
	pipe($rh, $wh);
	my $serializer	= RDF::Trine::Serializer::SparqlUpdate->new();
	$serializer->serialize_model_to_file($wh, $model);
	close($wh);
    my @expect = split "\n", <<'EOEXP';
MODIFY 
DELETE {}
INSERT {_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
_:greg <http://xmlns.com/foaf/0.1/homepage> <http://kasei.us/> .
_:greg <http://xmlns.com/foaf/0.1/name> "Greg" .
<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
EOEXP
    my @got = grep {$_} map {chomp; $_} (<$rh>);
    # warn Dumper \@got;
    is_deeply( [@expect], [@got], 'serialize_model_to_file');
}

{
	my $iter	= $model->get_statements( undef, $rdf->type, undef );
	
	my ($rh, $wh);
	pipe($rh, $wh);
	my $serializer	= RDF::Trine::Serializer::SparqlUpdate->new();
	$serializer->serialize_iterator_to_file($wh, $iter);
	close($wh);

    my @expect = split "\n", <<'EOEXP';
MODIFY 
DELETE {}
INSERT {_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
EOEXP
    my @got = grep {$_} map {chomp; $_} (<$rh>);
	
    # warn Dumper \@got;
	
    is_deeply( [@expect], [@got], 'serialize_iterator_to_file');
}

{
	my $serializer	= RDF::Trine::Serializer::SparqlUpdate->new();
	my $iter		= $model->get_statements( undef, $rdf->type, undef );
	my $string		= $serializer->serialize_iterator_to_string( $iter );
    my @expect = split "\n", <<'EOEXP';
MODIFY 
DELETE {}
INSERT {_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
EOEXP
    my @got = map { $_} (split "\n", $string);
	
    # warn Dumper \@got;
	
    is_deeply( [@expect], [@got], 'serialize_iterator_to_string');
}

{
	# my $iter		= $model->get_statements( undef, $rdf->type, undef );
	# my $string		= $serializer->serialize_iterator_to_string( $iter );
    my $st4		= RDF::Trine::Statement->new( $page, $rdf->type, $foaf->NotDocument );
    my $insert_model	= RDF::Trine::Model->temporary_model;
    my $delete_model	= RDF::Trine::Model->temporary_model;
    $delete_model->add_statement( $st3 );
    $insert_model->add_statement( $st4 );

	my $serializer	= RDF::Trine::Serializer::SparqlUpdate->new(delete_model => $delete_model);
    is( $serializer->{delete_model}, $delete_model, '$self->{delete_model} is set');
    my $string = $serializer->serialize_model_to_string( $insert_model );
    TODO: {
        local $TODO = 'Make options atomic per serialization';
        is( $serializer->{delete_model}, undef, '$self->{delete_model} is not set anymore');
    }
    my @expect = split "\n", <<'EOEXP';
MODIFY 
DELETE {<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
INSERT {<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/NotDocument> .
}
EOEXP
    my @got = map { $_} (split "\n", $string);
	
    # warn Dumper \@got;
	
    is_deeply( [@expect], [@got], 'serialize_iterator_to_string with delete clause');
}
