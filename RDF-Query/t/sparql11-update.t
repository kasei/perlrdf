use Test::More tests => 54;
use strict;
use warnings;

use RDF::Query;
use RDF::Trine;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.update          = TRACE, Screen
# 	
# 	log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr  = 0
# 	log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

{
	print "# insert data\n";
	my $model	= RDF::Trine::Model->temporary_model;
	is( $model->size, 0, 'empty model' );
	my $insert	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		INSERT DATA {
			<greg> a foaf:Person ; foaf:name "Greg" .
		}
END
	isa_ok( $insert, 'RDF::Query' );
	warn RDF::Query->error unless ($insert);
	$insert->execute( $model );
	is( $model->size, 2, 'expected model size' );
	
	{
		my $query	= RDF::Query->new('SELECT * WHERE { ?s a ?type }');
		my $iter	= $query->execute( $model );
		my @rows	= $iter->get_all;
		is( scalar(@rows), 1, 'expected result count' );
		isa_ok( $rows[0], 'RDF::Query::VariableBindings', 'expected variablebindings' );
		isa_ok( $rows[0]->{'s'}, 'RDF::Query::Node::Resource', 'expected subject resource' );
		isa_ok( $rows[0]->{'type'}, 'RDF::Query::Node::Resource', 'expected object resource' );
		is( $rows[0]->{'s'}->uri_value, 'greg', 'expected subject URI' );
		is( $rows[0]->{'type'}->uri_value, 'http://xmlns.com/foaf/0.1/Person', 'expected object Class' );
	}
	
	{
		my $query	= RDF::Query->new('SELECT * WHERE { <greg> ?p ?o }');
		my $iter	= $query->execute( $model );
		my @rows	= $iter->get_all;
		is( scalar(@rows), 2, 'expected result count' );
		foreach my $row (@rows) {
			isa_ok( $row, 'RDF::Query::VariableBindings', 'expected variablebindings' );
			isa_ok( $row->{'p'}, 'RDF::Query::Node::Resource', 'expected subject resource' );
			if ($row->{'p'}->uri_value eq 'http://xmlns.com/foaf/0.1/name') {
				isa_ok( $row->{'o'}, 'RDF::Query::Node::Literal', 'expected object literal' );
				is( $row->{'o'}->literal_value, 'Greg' );
			} else {
				isa_ok( $row->{'o'}, 'RDF::Query::Node::Resource', 'expected object resource' );
				is( $row->{'o'}->uri_value, 'http://xmlns.com/foaf/0.1/Person' );
			}
		}
	}
}

{
	print "# delete-insert update\n";
	my $model	= RDF::Trine::Model->temporary_model;
	is( $model->size, 0, 'empty model' );
	my $insert	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
		PREFIX foaf: <http://xmlns.com/foaf/0.1/>
		INSERT DATA {
			<william> a foaf:Person ; foaf:firstName "Bill" .
			<bill> a foaf:Person ; foaf:firstName "Bill" .
		}
END
	isa_ok( $insert, 'RDF::Query' );
	warn RDF::Query->error unless ($insert);
	$insert->execute( $model );
	is( $model->size, 4, 'expected model size' );
	
	my $update	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
		PREFIX foaf:  <http://xmlns.com/foaf/0.1/>
		DELETE { ?person foaf:firstName 'Bill' }
		INSERT { ?person foaf:firstName 'William' }
		WHERE {
			?person a foaf:Person ; foaf:firstName 'Bill'
		}
END
	$update->execute( $model );
	is( $model->size, 4, 'expected model size' );
	
	my $query	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
		PREFIX foaf:  <http://xmlns.com/foaf/0.1/>
		SELECT * WHERE {
			?person foaf:firstName ?name .
		}
END
	my $iter	= $query->execute( $model );
	my %expect	= map { $_ => 1 } qw(william bill);
	while (my $row = $iter->next) {
		isa_ok( $row, 'RDF::Query::VariableBindings' );
		isa_ok( $row->{'person'}, 'RDF::Query::Node::Resource' );
		isa_ok( $row->{'name'}, 'RDF::Query::Node::Literal' );
		is( $row->{'name'}->literal_value, 'William' );
		delete $expect{ $row->{person}->uri_value };
	}
	my @keys	= keys %expect;
	is_deeply( \@keys, [], 'seen 2 expected values' );
}

{
	print "# delete-insert update with WITH\n";
	my $model	= RDF::Trine::Model->temporary_model;
	is( $model->size, 0, 'empty model' );
	
	{
		my $insert	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
			PREFIX foaf: <http://xmlns.com/foaf/0.1/>
			INSERT DATA {
				GRAPH <g1> {
					<william> a foaf:Person ; foaf:firstName "Bill" .
					<bill> a foaf:Person ; foaf:firstName "Bill" .
				}
				GRAPH <g2> {
					<billy> a foaf:Person ; foaf:firstName "Bill" .
				}
			}
END
		isa_ok( $insert, 'RDF::Query' );
		warn RDF::Query->error unless ($insert);
		my ($plan, $ctx)	= $insert->prepare( $model );
		$insert->execute_plan( $plan, $ctx );
		is( $model->size, 6, 'expected model size' );
	}
	
	{
		my $update	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
			PREFIX foaf:  <http://xmlns.com/foaf/0.1/>
			WITH <g2>
			DELETE { ?person foaf:firstName 'Bill' }
			INSERT { ?person foaf:firstName 'William' }
			WHERE {
				?person a foaf:Person ; foaf:firstName 'Bill'
			}
END
		my ($plan, $ctx)	= $update->prepare( $model );
		$update->execute_plan( $plan, $ctx );
		is( $model->size, 6, 'expected model size' );
	}
	
	{
		my $query	= new RDF::Query ( <<"END", { lang => 'sparql11', update => 1 } );
			PREFIX foaf:  <http://xmlns.com/foaf/0.1/>
			SELECT * WHERE {
				GRAPH ?g {
					?person foaf:firstName ?name .
				}
			}
END
		my $iter	= $query->execute( $model );
		my %expect	= (
			william	=> [qw(g1 Bill)],
			bill	=> [qw(g1 Bill)],
			billy	=> [qw(g2 William)],
		);
		while (my $row = $iter->next) {
			isa_ok( $row, 'RDF::Query::VariableBindings' );
			isa_ok( $row->{'person'}, 'RDF::Query::Node::Resource' );
			isa_ok( $row->{'g'}, 'RDF::Query::Node::Resource' );
			isa_ok( $row->{'name'}, 'RDF::Query::Node::Literal' );
			my $data	= delete $expect{ $row->{'person'}->uri_value };
			my ($eg, $en)	= @$data;
			is( $row->{'g'}->uri_value, $eg, 'expected graph name' );
			is( $row->{'name'}->literal_value, $en, 'expected person name' );
		}
		my @keys	= keys %expect;
		is_deeply( \@keys, [], 'seen 3 expected values' );
	}
}
