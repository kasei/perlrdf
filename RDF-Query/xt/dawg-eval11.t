#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Encode qw(encode);

use URI::file;
use Test::More;
use File::Temp qw(tempfile);
use Scalar::Util qw(blessed reftype);
use Storable qw(dclone);

use RDF::Query;
use RDF::Query::Node qw(iri);
use RDF::Trine qw(statement);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Graph;
use RDF::Trine::Namespace qw(rdf rdfs);
use RDF::Trine::Iterator qw(smap);

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan		= TRACE, Screen
# #	log4perl.category.rdf.query.plan.join.pushdownnestedloop		= TRACE, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

our $debug				= 0;
our $debug_results		= 0;
our $STRICT_APPROVAL	= 0;
if ($] < 5.007003) {
	plan skip_all => 'perl >= 5.7.3 required';
	exit;
}

use Data::Dumper;
require XML::Simple;

plan qw(no_plan);
require "xt/dawg/earl.pl";
	
my $PATTERN		= shift(@ARGV) || '';
my $BNODE_RE	= qr/^(r|genid)[0-9A-F]+[r0-9]*$/;

no warnings 'once';

if ($PATTERN) {
	$debug			= 0;
	$debug_results	= 1;
}

warn "PATTERN: ${PATTERN}\n" if ($PATTERN and $debug);

my @manifests;
my $model	= new_model( map { glob( "xt/dawg11/$_/manifest.ttl" ) }
	qw(
		aggregates
		bind
		delete
		delete-data
		delete-where
		functions
		grouping
		negation
		project-expression
		property-path
		subquery
	) );
print "# Using model object from " . ref($model) . "\n";

{
	my $ns		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
	my $inc		= $ns->include;
	
	
	my $objects	= $model->objects( undef, $inc );
	if (my $list = $objects->next) {
		my $first		= $rdf->first;
		my $rest		= $rdf->rest;
		while ($list and not $list->equal( $rdf->nil )) {
			my $value			= get_first_obj( $model, $list, $first );
			$list				= get_first_obj( $model, $list, $rest );
			my $manifest		= $value->uri_value;
			next unless (defined($manifest));
			$manifest	= relativeize_url( $manifest );
			push(@manifests, $manifest) if (defined($manifest));
		}
	}
	
	if ($debug) {
		use Data::Dumper;
		warn 'manifests: ' . Dumper(\@manifests);
	}
	add_to_model( $model, @manifests );
}

my $earl	= init_earl( $model );
my $type	= RDF::Trine::Node::Resource->new( "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" );
my $qevalt	= RDF::Trine::Node::Resource->new( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#QueryEvaluationTest" );
my $uevalt	= RDF::Trine::Node::Resource->new( "http://www.w3.org/2009/sparql/tests/test-update#UpdateEvaluationTest" );
my $mfname	= RDF::Trine::Node::Resource->new( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#name" );

{
	print "# Query Evaluation Tests\n";
	my $stream	= $model->get_statements( undef, $type, $qevalt );
	while (my $statement = $stream->next()) {
		my $test		= $statement->subject;
		my $name		= get_first_literal( $model, $test, $mfname );
		unless ($test->uri_value =~ /$PATTERN/) {
			next;
		}
		warn "### query eval test: " . $test->as_string . " >>> " . $name->literal_value . "\n" if ($debug);
		query_eval_test( $model, $test, $earl );
	}
}

{
	print "# Update Evaluation Tests\n";
	my $stream	= $model->get_statements( undef, $type, $uevalt );
	while (my $statement = $stream->next()) {
		my $test		= $statement->subject;
		my $name		= get_first_literal( $model, $test, $mfname );
		unless ($test->uri_value =~ /$PATTERN/) {
			next;
		}
		warn "### update eval test: " . $test->as_string . " >>> " . $name->literal_value . "\n" if ($debug);
		update_eval_test( $model, $test, $earl );
	}
}

open( my $fh, '>', 'earl-eval-11.ttl' ) or die $!;
print {$fh} earl_output( $earl );
close($fh);

################################################################################

sub update_eval_test {
	my $model		= shift;
	my $test		= shift;
	my $earl		= shift;
	my $man			= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
	my $rq			= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-query#');
	my $dawgt		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#');
	my $ut			= RDF::Trine::Namespace->new('http://www.w3.org/2009/sparql/tests/test-update#');
	my $mfact		= $man->action;
	my $mfres		= $man->result;
	my $qtquery		= $rq->query;
	my $qtdata		= $rq->data;
	my $qtgdata		= $rq->graphData;
	my $reqs		= $man->requires;
	my $approval	= $dawgt->approval;
	
	my $action		= get_first_obj( $model, $test, $mfact );
	my $result		= get_first_obj( $model, $test, $mfres );
	my $req			= get_first_obj( $model, $test, $reqs );
	my $approved	= get_first_obj( $model, $test, $approval );
	my $queryd		= get_first_obj( $model, $action, $ut->request );
	my $data		= get_first_obj( $model, $action, $ut->data );
	my @gdata		= get_all_obj( $model, $action, $ut->graphData );
	
	if ($STRICT_APPROVAL) {
		unless ($approved) {
			warn "- skipping test because it isn't approved\n" if ($debug);
			return;
		}
		if ($approved->uri_value eq 'http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#NotClassified') {
			warn "- skipping test because its approval is dawgt:NotClassified\n" if ($debug);
			return;
		}
	}
	
	my $uri					= URI->new( $queryd->uri_value );
	my $filename			= $uri->file;
	my (undef,$base,undef)	= File::Spec->splitpath( $filename );
	$base					= "file://${base}";
	warn "Loading SPARQL query from file $filename" if ($debug);
	my $sparql				= do { local($/) = undef; open(my $fh, '<', $filename) or do { fail("$!: $filename; " . $test->as_string); return }; binmode($fh, ':utf8'); <$fh> };

	my $q			= $sparql;
	$q				=~ s/\s+/ /g;
	if ($debug) {
		warn "### test     : " . $test->as_string . "\n";
		warn "# sparql     : $q\n";
		warn "# data       : " . $data->as_string if (blessed($data));
		warn "# graph data : " . $_->as_string for (@gdata);
		warn "# result     : " . $result->as_string;
		warn "# requires   : " . $req->as_string if (blessed($req));
	}
	
	print STDERR "constructing model... " if ($debug);
	my ($test_model)	= new_model();
	try {
		if (blessed($data)) {
			add_to_model( $test_model, $data->uri_value );
		}
	} catch Error with {
		my $e	= shift;
		fail($test->as_string);
		earl_fail_test( $earl, $test, $e->text );
		print "# died: " . $test->as_string . ": $e\n";
		return;
	};
	
	foreach my $gdata (@gdata) {
		my $data	= get_first_obj( $model, $gdata, $ut->graph );
		my $graph	= get_first_obj( $model, $gdata, $rdfs->label );
		my $uri		= $graph->literal_value;
		try {
			warn "test data file: " . $data->uri_value . "\n" if ($debug);
			RDF::Trine::Parser->parse_url_into_model( $data->uri_value, $test_model, context => RDF::Trine::Node::Resource->new($uri) );
		} catch Error with {
			my $e	= shift;
			fail($test->as_string);
			earl_fail_test( $earl, $test, $e->text );
			print "# died: " . $test->as_string . ": $e\n";
			return;
		};
	}
	
	my $result_status	= get_first_obj( $model, $result, $ut->result );
	my @resgdata			= get_all_obj( $model, $result, $ut->graphData );
	my $expected_model	= new_model();
	my $resdata		= get_first_obj( $model, $result, $ut->data );
	try {
		if (blessed($resdata)) {
			RDF::Trine::Parser->parse_url_into_model( $resdata->uri_value, $expected_model );
		}
	} catch Error with {
		my $e	= shift;
		fail($test->as_string);
		earl_fail_test( $earl, $test, $e->text );
		print "# died: " . $test->as_string . ": $e\n";
		return;
	};
	foreach my $gdata (@resgdata) {
		my $data	= get_first_obj( $model, $gdata, $ut->graph );
		my $graph	= get_first_obj( $model, $gdata, $rdfs->label );
		my $uri		= $graph->literal_value;
		try {
			warn "expected result data file: " . $data->uri_value . "\n" if ($debug);
			RDF::Trine::Parser->parse_url_into_model( $data->uri_value, $expected_model, context => RDF::Trine::Node::Resource->new($uri) );
		} catch Error with {
			my $e	= shift;
			fail($test->as_string);
			earl_fail_test( $earl, $test, $e->text );
			print "# died: " . $test->as_string . ": $e\n";
			return;
		};
	}
	
	my $ok	= 0;
	eval {
		my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', update => 1 } );
		unless ($query) {
			warn RDF::Query->error;
			return;
		}
		$query->execute( $test_model );
		
		my $test_graph		= RDF::Trine::Graph->new( $test_model );
		my $expected_graph	= RDF::Trine::Graph->new( $expected_model );
		
		
		if ($debug_results) {
			warn "GOT: ---------------------------------------------\n";
			warn $test_model->as_string;
			warn "EXPECTED: ----------------------------------------\n";
			warn $expected_model->as_string;
			warn "--------------------------------------------------\n";
		}
		
		my $eq	= $test_graph->equals( $expected_graph );
		$ok	= is( $eq, 1, $test->as_string );
	};
	if ($ok) {
		earl_pass_test( $earl, $test );
	} else {
		earl_fail_test( $earl, $test, $@ );
		print "# failed: " . $test->as_string . "\n";
	}
	
	print STDERR "ok\n" if ($debug);
}

sub query_eval_test {
	my $model		= shift;
	my $test		= shift;
	my $earl		= shift;
	my $man			= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
	my $rq			= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-query#');
	my $dawgt		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#');
	my $mfact		= $man->action;
	my $mfres		= $man->result;
	my $qtquery		= $rq->query;
	my $qtdata		= $rq->data;
	my $qtgdata		= $rq->graphData;
	my $reqs		= $man->requires;
	my $approval	= $dawgt->approval;
	
	my $action		= get_first_obj( $model, $test, $mfact );
	my $result		= get_first_obj( $model, $test, $mfres );
	my $req			= get_first_obj( $model, $test, $reqs );
	my $approved	= get_first_obj( $model, $test, $approval );
	my $queryd		= get_first_obj( $model, $action, $qtquery );
	my $data		= get_first_obj( $model, $action, $qtdata );
	my @gdata		= get_all_obj( $model, $action, $qtgdata );
	
	if ($STRICT_APPROVAL) {
		unless ($approved) {
			warn "- skipping test because it isn't approved\n" if ($debug);
			return;
		}
		if ($approved->uri_value eq 'http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#NotClassified') {
			warn "- skipping test because its approval is dawgt:NotClassified\n" if ($debug);
			return;
		}
	}
	
	my $uri					= URI->new( $queryd->uri_value );
	my $filename			= $uri->file;
	my (undef,$base,undef)	= File::Spec->splitpath( $filename );
	$base					= "file://${base}";
	warn "Loading SPARQL query from file $filename" if ($debug);
	my $sparql				= do { local($/) = undef; open(my $fh, '<', $filename) or do { warn("$!: $filename; " . $test->as_string); return }; binmode($fh, ':utf8'); <$fh> };
	
	my $q			= $sparql;
	$q				=~ s/\s+/ /g;
	if ($debug) {
		warn "### test     : " . $test->as_string . "\n";
		warn "# sparql     : $q\n";
		warn "# data       : " . $data->as_string if (blessed($data));
		warn "# graph data : " . $_->as_string for (@gdata);
		warn "# result     : " . $result->as_string;
		warn "# requires   : " . $req->as_string if (blessed($req));
	}
	
	print STDERR "constructing model... " if ($debug);
	my ($test_model)	= new_model();
	try {
		if (blessed($data)) {
			add_to_model( $test_model, $data->uri_value );
		}
	} catch Error with {
		my $e	= shift;
		fail($test->as_string);
		earl_fail_test( $earl, $test, $e->text );
		print "# died: " . $test->as_string . ": $e\n";
		return;
	};
	print STDERR "ok\n" if ($debug);
	
	my $resuri		= URI->new( $result->uri_value );
	my $resfilename	= $resuri->file;
	
	TODO: {
		local($TODO)	= (blessed($req)) ? "requires " . $req->as_string : '';
		my $comment;
		my $ok	= eval {
			if ($debug) {
				my $q	= $sparql;
				$q		=~ s/([\x{256}-\x{1000}])/warn ord($1); '\x{' . sprintf('%x', ord($1)) . '}'/eg;
				warn $q;
			}
			print STDERR "getting actual results... " if ($debug);
			my $actual		= get_actual_results( $test_model, $sparql, $base, @gdata );
			print STDERR "ok\n" if ($debug);
			
			print STDERR "getting expected results... " if ($debug);
			my $type		= (blessed($actual) and $actual->isa( 'RDF::Trine::Iterator::Graph' )) ? 'graph' : '';
			my $expected	= get_expected_results( $resfilename, $type );
			print STDERR "ok\n" if ($debug);
			
		#	warn "comparing results...";
			my $ok			= compare_results( $expected, $actual, $earl, $test->as_string, \$comment );
		};
		warn $@ if ($@);
		if ($ok) {
			earl_pass_test( $earl, $test );
		} else {
			earl_fail_test( $earl, $test, $comment );
			print "# failed: " . $test->as_string . "\n";
# 			die;	 # XXX
		}
	}
}


exit;

######################################################################


sub new_model {
	my @files		= @_;
	my $store		= RDF::Trine::Store::Memory->temporary_store;
	my $model		= RDF::Trine::Model->new( $store );
	my @uris		= file_uris(@files);
	foreach my $u (@uris) {
		warn "loading uri: $u" if ($debug > 1);
		add_to_model( $model, $u );
	}
	return $model;
}

sub add_to_model {
	my $model	= shift;
	my @files	= @_;
	
	foreach my $file (@files) {
		RDF::Trine::Parser->parse_url_into_model( $file, $model );
	}
}

sub add_to_model_named {
	my $store	= shift;
	my $model	= RDF::Query->get_model( $store );
	my @files	= @_;
	foreach my $uri (@files) {
		RDF::Trine::Parser->parse_url_into_model( $uri, $model, context => $uri );
	}
	return 1;
}

sub add_source_to_model {
	my $model	= shift;
	my @sources	= @_;
	foreach my $source (@sources) {
		open( my $fh, '<', \$source );
		RDF::Trine::Parser->parse_into_model( 'http://kasei.us/ns#', $fh, $model );
	}
}

sub file_uris {
	my @files	= @_;
	return map { "$_" } map { URI::file->new_abs( $_ ) } @files;
}

######################################################################

sub get_actual_results {
	my $model	= shift;
	my $sparql	= shift;
	my $base	= shift;
	my @gdata	= @_;
	my $query	= RDF::Query->new( $sparql, $base, undef, 'sparql11', load_data => 1 );
	
	unless ($query) {
		warn RDF::Query->error if ($debug or $PATTERN);
		return;
	}
	
	my $results	= $query->execute_with_named_graphs( $model, @gdata );
	if ($results->is_bindings) {
		my @keys	= $results->binding_names;
		my @results;
		while (my $row = $results->next) {
			my %data;
			foreach my $key (keys %$row) {
				my $value	= node_as_string( $row->{ $key } );
				if (defined $value) {
#					my $string	= $bridge->as_string( $row->{ $key } );
					$data{ $key }	= $value;
				}
			}
			push(@results, \%data);
		}
		return \@results;
	} elsif ($results->is_boolean) {
		return sprintf( '"%s"^^<http://www.w3.org/2001/XMLSchema#boolean>', ($results->get_boolean) ? 'true' : 'false' );
	} elsif ($results->is_graph) {
		return $results;
# 		my $xml		= $results->as_xml;
# 		my ($bridge, $model)	= new_model();
# 		add_source_to_model( $bridge, $xml );
# 		return ($bridge);
	}
}

sub get_expected_results {
	my $file		= shift;
	my $type		= shift;
	
	if ($type eq 'graph') {
		my $model	= new_model( $file );
		my $stream	= $model->get_statements();
		return $stream;
	} elsif ($file =~ /[.]srx/) {
		my $data		= do { local($/) = undef; open(my $fh, '<', $file) or die $!; binmode($fh, ':utf8'); <$fh> };
		my $xml			= XML::Simple::XMLin( $file );
		
		if (exists $xml->{results}) {
			my $results	= $xml->{results}{result};
#			die Dumper($results) unless (reftype($results) eq 'ARRAY');
			my @xml_results	= (ref($results) and reftype($results) eq 'ARRAY')
							? @{ $results }
							: (defined($results))
								? ($results)
								: ();
			
			my @results;
			my %bnode_map;
			my $bnode_next	= 0;
			foreach my $r (@xml_results) {
				my $binding	= $r->{binding};
				my @bindings;
				if (exists $binding->{name}) {
					my $name	= $binding->{name};
					push(@bindings, [$name, $binding]);
				} else {
					foreach my $key (keys %$binding) {
						push(@bindings, [$key, $binding->{$key}]);
					}
				}
				
				my $result	= {};
				foreach my $data (@bindings) {
					my $name	= $data->[0];
					my $binding	= $data->[1];
					
					my $type	= reftype($binding);
					if ($type eq 'HASH') {
						if (exists($binding->{literal})) {
							if (ref($binding->{literal})) {
								my $value	= $binding->{literal}{content};
								$value		= '' unless (defined($value));
								my $lang	= $binding->{literal}{'xml:lang'};
								my $dt		= $binding->{literal}{'datatype'};
								my $string	= literal_as_string( $value, $lang, $dt );
	#							push(@results, { $name => $string });
								$result->{ $name }	= $string;
							} else {
								my $string	= literal_as_string( $binding->{literal}, undef, undef );
	#							push(@results, { $name => $string });
								$result->{ $name }	= $string;
							}
						} elsif (exists($binding->{bnode})) {
							my $bnode	= $binding->{bnode};
							my $id;
							if (exists $bnode_map{ $bnode }) {
								$id	= $bnode_map{ $bnode };
							} else {
								$id	= join('', 'r', $bnode_next++);
								$bnode_map{ $bnode }	= $id;
							}
	#						push(@results, { $name => $id });
							$result->{ $name }	= $id;
						} elsif (exists($binding->{uri})) {
							$result->{ $name }	= $binding->{uri};
	#						push(@results, { $name => $binding->{uri} });
						} else {
	#						push(@results, {});
	#						die "Uh oh. Unrecognized binding node type: " . Dumper($binding);
						}
					} elsif ($type eq 'ARRAY') {
						die "Uh oh. ARRAY binding type: " . Data::Dumper::Dumper($binding);
					} else {
						die "Uh oh. Unknown result reftype: " . Data::Dumper::Dumper($r);
					}
				}
				push(@results, $result);
			}
			return \@results;
		} elsif (exists $xml->{boolean}) {
			return sprintf( '"%s"^^<http://www.w3.org/2001/XMLSchema#boolean>', $xml->{boolean} );
		}
	} else {
		my $model		= new_model( $file );
		my $p_type		= iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
		my $p_rv		= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#resultVariable');
		my $p_solution	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#solution');
		my $p_binding	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#binding');
		my $p_boolean	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#boolean');
		my $p_value		= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#value');
		my $p_variable	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#variable');
		my $t_rs		= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet');
		my $rss			= $model->subjects( $p_type, $t_rs );
		my $rs			= $rss->next;
		
		if (my $bool = get_first_as_string( $model, $rs, $p_boolean )) {
			return $bool;
		} else {
			my $vnodess		= $model->objects( $rs, $p_rv );
			my @vars		= map { $_->literal_value } $vnodess->get_all();
			my $rowss		= $model->objects( $rs, $p_solution );
			
			my @results;
			while (my $row = $rowss->next) {
				my %data;
				my $stream		= $model->objects( $row, $p_binding );
				my @bindings	= $stream->get_all();
#				my @bindings	= $model->targets( $row, $p_binding );
				foreach my $b (@bindings) {
					my $var		= get_first_as_string( $model, $b, $p_variable );
					my $value	= get_first_as_string( $model, $b, $p_value );
					$data{ $var }	= $value;
				}
				push(@results, \%data);
			}
			return \@results;
		}
	}
}

sub model_to_arrayref {
	my $model	= shift;
	my $stream	= $model->get_statements();
	my @data;
	my %bnode_map;
	while(my $statement = $stream->next) {
		my $s			= $statement->subject;
		my $p			= $statement->predicate;
		my $o			= $statement->object;
		my @triple;
		foreach my $node ($s, $p, $o) {
			if (blessed($node) and $node->isa('RDF::Trine::Node::Blank')) {
				my $id		= $node->blank_identifier;
				unless (exists( $bnode_map{ $id } )) {
					my $blank			= [];
					$bnode_map{ $id }	= $blank;
				}
				push( @triple, $bnode_map{ $id } );
			} elsif (blessed($node) and $node->isa('RDF::Trine::Node::Resource')) {
				push( @triple, $node->uri_value );
			} else {
				push( @triple, node_as_string( $node ) );
			}
		}
		push(@data, \@triple);
	}
	return \@data;
}

sub compare_results {
	my $expected	= shift;
	my $actual		= shift;
	my $earl		= shift;
	my $test		= shift;
	my $comment		= shift || do { my $foo; \$foo };
	my $TODO		= shift;
	my $_expected	= eval { dclone($expected) };
	my $_actual		= eval { dclone($actual) };
	if (not(ref($actual))) {
		my $ok	= is( $actual, $expected, $test );
		warn_results( $_expected, $_actual ) if ($debug_results and not($ok));
		return $ok;
	} elsif (blessed($actual) and $actual->isa('RDF::Trine::Iterator::Graph')) {
		die unless (blessed($expected) and $expected->isa('RDF::Trine::Iterator::Graph'));
		
		local($debug)	= 1 if ($PATTERN);
		warn ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n" if ($debug);
		my $actualxml		= $actual->as_xml;
		warn $actualxml if ($debug);
		warn "-------------------------------\n" if ($debug);
		my $expectxml		= $expected->as_xml;
		warn $expectxml if ($debug);
		
		warn "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n" if ($debug);
		
		my $act_graph	= RDF::Trine::Graph->new( $actual );
		my $exp_graph	= RDF::Trine::Graph->new( $expected );
		my $eq	= $act_graph->equals( $exp_graph );
		return is( $eq, 1, $test );
	} else {
		my %actual_flat;
		foreach my $i (0 .. $#{ $actual }) {
			my $row	= $actual->[ $i ];
			my @keys	= sort keys %$row;
			my $key		= join("\xFF", map { encode('utf8', $row->{$_}) } @keys);
			push( @{ $actual_flat{ $key } }, [ $i, $row ] );;
		}
		
		my %bnode_map;
		my $bnode	= 1;
	#	local($debug)	= 1;
		EXPECTED: foreach my $row (@$expected) {
			my @keys	= keys %$row;
			my @skeys	= sort @keys;
			my @values	= map { $row->{$_} } @skeys;
			my $key		= join("\xFF", map { encode('utf8', $_) } @values);
			if (exists($actual_flat{ $key })) {
				my $i	= $actual_flat{ $key }[0][0];
				shift(@{ $actual_flat{ $key } });
				unless (scalar(@{ $actual_flat{ $key } })) {
					$actual->[ $i ]	= undef;
					delete $actual_flat{ $key };
				}
				
				next; #next EXPECTED;
#				pass( "expected result found: " . join(', ', @{$row}{ @keys }) );
#				return 1;
			} else {
				warn "looking for an actual result matching the expected: " . Data::Dumper::Dumper($row) if ($debug);
				warn "remaining actual results: " . Data::Dumper::Dumper($actual) if ($debug);
				my $passed	= 0;
				my $skipped	= 0;
				my %seen;
	#			ACTUAL: while (keys %actual_flat) {
				ACTUAL: foreach my $actual_key (keys %actual_flat) {
					# while there are remaining actual results,
					# keep trying to match them with expected results
					
					if ($seen{ $actual_key }++) {
						$skipped++;
						next; #next ACTUAL;
					}
					
					my $actual_row		= $actual_flat{ $actual_key }[0][ 1 ];
					warn "\t actual result: " . Data::Dumper::Dumper($actual_row) if ($debug);
					my @actual_keys		= keys %{ $actual_row };
					my @actual_values	= map { $actual_row->{$_} } sort @actual_keys;
					
					my $ok	= 1;
					PROP: foreach my $i (0 .. $#values) {
						# try to match each property of this actual result
						# with the values from the expected result.
						
						my $actualv		= $actual_values[ $i ];
						my $expectedv	= $values[ $i ];
						if ($expectedv eq $actualv) {
							warn "\tvalues of $skeys[$i] match. going to next property\n" if ($debug);
							next; #next PROP;
						}
						
						if ($values[ $i ] =~ $BNODE_RE and $actual_values[ $i ] =~ $BNODE_RE) {
							my $id;
							if (exists $bnode_map{ actual }{ $actual_values[ $i ] }) {
								my $id	= $bnode_map{ actual }{ $actual_values[ $i ] };
								no warnings 'uninitialized';
								if ($id == $bnode_map{ expected }{ $values[ $i ] }) {
									warn "\tvalues of $skeys[$i] are merged bnodes. going to next property\n" if ($debug);
									next; #next PROP;
								} else {
									warn 'bnode map: ' . Data::Dumper::Dumper(\%bnode_map) if ($debug);
									next ACTUAL;
								}
							} elsif (exists $bnode_map{ expected }{ $values[ $i ] }) {
								my $id	= $bnode_map{ expected }{ $values[ $i ] };
								no warnings 'uninitialized';
								if ($id == $bnode_map{ actual }{ $actual_values[ $i ] }) {
									warn "\tvalues of $skeys[$i] are merged bnodes. going to next property\n" if ($debug);
									next; #next PROP;
								}
							} else {
								my $id	= $bnode++;
								warn "\tvalues of $skeys[$i] are both bnodes ($actual_values[ $i ] and $values[ $i ]). merging them and going to next property\n" if ($debug);
								$bnode_map{ actual }{ $actual_values[ $i ] }	= $id;
								$bnode_map{ expected }{ $values[ $i ] }			= $id;
								next; #next PROP;
							}
						}
						
						# we didn't match this property, so this actual result doesn't
						# match the expected result. break out and try another actual result.
						$ok	= 0;
						next ACTUAL;
					}
					if ($ok) {
						$passed	= 1;
#						pass( "expected result found: " . join(', ', @{$row}{ @keys }) );
						my $i	= $actual_flat{ $actual_key }[0][0];
						shift(@{ $actual_flat{ $actual_key } });
						unless (scalar(@{ $actual_flat{ $actual_key } })) {
							$actual->[ $i ]	= undef;
							delete $actual_flat{ $actual_key };
						}
					}
				}
				
				unless ($passed) {
	#				warn 'did not pass test. actual data: ' . Dumper($actual);
					warn_results( $_expected, $_actual ) if ($debug_results);
					$$comment	= "expected but didn't find: " . join(', ', @{ $row }{ @keys });
					fail( "$test: $$comment" );
					return 0;
				}
			}
		}
		
		my @remaining	= keys %actual_flat;
		warn "remaining: " . Data::Dumper::Dumper(\@remaining) if ($debug and (@remaining));
		my $ok	= scalar(@remaining) == 0;
		warn_results( $_expected, $_actual ) if ($debug_results and not($ok));
		ok( $ok, "$test: no unchecked results" );
		return $ok;
	}
}

######################################################################


sub get_first_as_string  {
	my $node	= get_first_obj( @_ );
	return unless $node;
	return node_as_string( $node );
}

sub node_as_string {
	my $node	= shift;
	if ($node) {
		no warnings 'once';
		if ($node->is_resource) {
			return $node->uri_value;
		} elsif ($node->is_literal) {
			my $value	= $node->literal_value;
			my $lang	= $node->literal_value_language;
			my $dt		= $node->literal_datatype;
			return literal_as_string( $value, $lang, $dt );
		} else {
			return $node->blank_identifier;
		}
	} else {
		return;
	}
}


sub literal_as_string {
	my $value	= shift;
	my $lang	= shift;
	my $dt		= shift;
	if (defined $value) {
		my $string	= qq["$value"];
		if ($lang) {
			$string	.= '@' . lc($lang);
		} elsif ($dt) {
			$string	.= '^^<' . $dt . '>';
		}
		return $string;
	} else {
		return;
	}
}


sub get_first_literal {
	my $node	= get_first_obj( @_ );
	return $node;
#	return $node ? Encode::decode('utf8', $bridge->literal_value($node)) : undef;
}

sub get_all_literal {
	my @nodes	= get_all_obj( @_ );
	return @nodes;
#	return map { Encode::decode('utf8', $bridge->literal_value($_)) } grep { $bridge->isa_literal($_) } @nodes;
}

sub get_first_uri {
	my $node	= get_first_obj( @_ );
	return $node ? $node->uri_value : undef;
}

sub get_all_uri {
	my @nodes	= get_all_obj( @_ );
	return map { $_->uri_value } grep { defined($_) and $_->isa('RDF::Trine::Node::Resource') } @nodes;
}

sub get_first_obj {
	my $model	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : RDF::Trine::Node::Resource->new( $_ ) } @uris;
	foreach my $pred (@preds) {
		my $targets	= $model->objects( $node, $pred );
		while (my $node = $targets->next) {
			return $node if ($node);
		}
	}
}

sub get_all_obj {
	my $model	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : RDF::Trine::Node::Resource->new( $_ ) } @uris;
	my @objs;
	
	my @streams;
	foreach my $pred (@preds) {
		push(@streams, $model->get_statements( $node, $pred, undef ));
	}
	my $stream	= shift(@streams);
	while (@streams) {
		$stream	= $stream->concat( shift(@streams) );
	}
	my $targets	= smap { $_->object } $stream;
	return $targets->get_all();
}

sub relativeize_url {
	my $uri	= shift;
	if ($uri =~ /^http:/) {
		$uri	=~ s{^http://www.w3.org/2001/sw/DataAccess/tests/}{xt/dawg/data-r2/};
		$uri	= 'file://' . File::Spec->rel2abs( $uri );
	}
	return $uri;
}

sub warn_results {
	my $expected	= shift;
	my $actual		= shift;
	warn 'compare_results: ' . Data::Dumper->Dump([$expected, $actual], [qw(expected actual)]);
}
