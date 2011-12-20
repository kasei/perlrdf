use Test::More tests => 11;
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
INSERT {_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
_:greg <http://xmlns.com/foaf/0.1/homepage> <http://kasei.us/> .
_:greg <http://xmlns.com/foaf/0.1/name> "Greg" .
<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
WHERE {}
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
INSERT {_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
WHERE {}
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
INSERT {_:greg <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Person> .
<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
WHERE {}
EOEXP
    my @got = grep { $_ } (split "\n", $string);
	
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
DELETE {<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/Document> .
}
INSERT {<http://kasei.us/> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://xmlns.com/foaf/0.1/NotDocument> .
}
WHERE {}
EOEXP
    my @got = grep { $_} (split "\n", $string);
	
    # warn Dumper \@got;
	
    is_deeply( [@expect], [@got], 'serialize_iterator_to_string with delete clause');
}

{
    require_ok('RDF::Endpoint');
    require_ok('LWP::Protocol::PSGI');
    my $end_config  = {
        store => 'Memory',
        endpoint    => {
            endpoint_path   => '/',
            update      => 1,
            load_data   => 1,
            html        => {
                resource_links  => 1,    # turn resources into links in HTML query result pages
                embed_images    => 0,    # display foaf:Images as images in HTML query result pages
                image_width     => 200,  # with 'embed_images', scale images to this width
            },
            service_description => {
                default         => 1,    # generate dataset description of the default graph
                named_graphs    => 1,    # generate dataset description of the available named graphs
            },
        },
    };
    my $sparql_model = RDF::Trine::Model->temporary_model;
    my $end     = RDF::Endpoint->new( $sparql_model, $end_config );
    my $end_app = sub {
        my $env 	= shift;
        my $req 	= Plack::Request->new($env);
        my $resp	= $end->run( $req );
        return $resp->finalize;
    };
    LWP::Protocol::PSGI->register($end_app);
    my $ua = LWP::UserAgent->new;

    my $serializer	= RDF::Trine::Serializer::SparqlUpdate->new;
    my $string = $serializer->serialize_model_to_string( $model );
    my ($type) = $serializer->media_types;

    my $req = HTTP::Request->new(POST => 'http://localhost/?sparql');
    $req->header(Content_Type => $type);
    $req->content( $string );
    # warn Dumper $sparql_model->size;
    is( $sparql_model->size, 0, 'Model empty before request');
    my $resp = $ua->request( $req );
    is( $sparql_model->size, 4, 'request addded 4 statements.');
}
