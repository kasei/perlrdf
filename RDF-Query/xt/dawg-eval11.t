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
use Math::Combinatorics qw(permute);

use RDF::Query;
use RDF::Query::Node qw(iri blank literal variable);
use RDF::Trine qw(statement);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Graph;
use RDF::Trine::Namespace qw(rdf rdfs xsd);
use RDF::Trine::Iterator qw(smap);
# use RDF::Redland;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.update		= TRACE, Screen
# #	log4perl.category.rdf.query.plan.join.pushdownnestedloop		= TRACE, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

our $debug				= 0;
our $STRICT_APPROVAL	= 0;
if ($] < 5.007003) {
	plan skip_all => 'perl >= 5.7.3 required';
	exit;
}

use Data::Dumper;
require XML::Simple;

plan qw(no_plan);
require "xt/dawg/earl.pl";
	
my $PATTERN	= '';
my %args;

while (defined(my $opt = shift)) {
	if ($opt =~ /^-(.*)$/) {
		$args{ $1 }	= 1;
	} elsif ($opt eq '-v') {
		$debug++;
	} else {
		$PATTERN	= $opt;
	}
}


no warnings 'once';

if ($PATTERN) {
# 	$debug			= 1;
}

warn "PATTERN: ${PATTERN}\n" if ($PATTERN and $debug);

my $model		= RDF::Trine::Model->temporary_model;
my @manifests	= map { $_->as_string } map { URI::file->new_abs( $_ ) } map { glob( "xt/dawg11/$_/manifest.ttl" ) }
	qw(
		aggregates
		basic-update
		bind
		clear
		construct
		delete
		delete-data
		delete-insert
		delete-where
		drop
		functions
		grouping
		json-res
		negation
		project-expression
		property-path
		subquery
	);
foreach my $file (@manifests) {
	RDF::Trine::Parser->parse_url_into_model( $file, $model, canonicalize => 1 );
}

my $earl	= init_earl( $model );
my $mf		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
my $ut		= RDF::Trine::Namespace->new('http://www.w3.org/2009/sparql/tests/test-update#');
my $rq		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-query#');
my $dawgt	= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#');

{
	my @manifests	= $model->subjects( $rdf->type, $mf->Manifest );
	foreach my $m (@manifests) {
		warn "Manifest: " . $m->as_string . "\n" if ($debug > 1);
		my ($list)	= $model->objects( $m, $mf->entries );
		my @tests	= $model->get_list( $list );
		foreach my $test (@tests) {
			if ($model->count_statements($test, $rdf->type, $mf->QueryEvaluationTest)) {
				my ($name)	= $model->objects( $test, $mf->name );
				unless ($test->uri_value =~ /$PATTERN/) {
					next;
				}
				warn "### query eval test: " . $test->as_string . " >>> " . $name->literal_value . "\n" if ($debug);
				query_eval_test( $model, $test, $earl );
			}
			
			if ($model->count_statements($test, $rdf->type, $ut->UpdateEvaluationTest)) {
				my ($name)	= $model->objects( $test, $mf->name );
				unless ($test->uri_value =~ /$PATTERN/) {
					next;
				}
				warn "### update eval test: " . $test->as_string . " >>> " . $name->literal_value . "\n" if ($debug);
				update_eval_test( $model, $test, $earl );
			}
		}
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
	
	my ($action)	= $model->objects( $test, $mf->action );
	my ($result)	= $model->objects( $test, $mf->result );
	my ($req)		= $model->objects( $test, $mf->requires );
	my ($approved)	= $model->objects( $test, $dawgt->approval );
	my ($queryd)	= $model->objects( $action, $ut->request );
	my ($data)		= $model->objects( $action, $ut->data );
	my @gdata		= $model->objects( $action, $ut->graphData );
	
	if ($STRICT_APPROVAL) {
		unless ($approved) {
			warn "- skipping test because it isn't approved\n" if ($debug);
			return;
		}
		if ($approved->equal( $dawgt->NotClassified)) {
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
	my ($test_model)	= RDF::Trine::Model->temporary_model;
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
	} except {
		my $e	= shift;
		die $e->text;
	} otherwise {
		warn '*** failed to construct model';
	};
	
	foreach my $gdata (@gdata) {
		my ($data)	= ($model->objects( $gdata, $ut->data ))[0] || ($model->objects( $gdata, $ut->graph ))[0];
		my ($graph)	= $model->objects( $gdata, $rdfs->label );
		my $uri		= $graph->literal_value;
		try {
			warn "test data file: " . $data->uri_value . "\n" if ($debug);
			RDF::Trine::Parser->parse_url_into_model( $data->uri_value, $test_model, context => RDF::Trine::Node::Resource->new($uri), canonicalize => 1 );
		} catch Error with {
			my $e	= shift;
			fail($test->as_string);
			earl_fail_test( $earl, $test, $e->text );
			print "# died: " . $test->as_string . ": $e\n";
			return;
		};
	}
	
	my ($result_status)	= $model->objects( $result, $ut->result );
	my @resgdata		= $model->objects( $result, $ut->graphData );
	my $expected_model	= RDF::Trine::Model->temporary_model;
	my ($resdata)		= $model->objects( $result, $ut->data );
	try {
		if (blessed($resdata)) {
			RDF::Trine::Parser->parse_url_into_model( $resdata->uri_value, $expected_model, canonicalize => 1 );
		}
	} catch Error with {
		my $e	= shift;
		fail($test->as_string);
		earl_fail_test( $earl, $test, $e->text );
		print "# died: " . $test->as_string . ": $e\n";
		return;
	};
	foreach my $gdata (@resgdata) {
		my ($data)	= ($model->objects( $gdata, $ut->data ))[0] || ($model->objects( $gdata, $ut->graph ))[0];
		my ($graph)	= $model->objects( $gdata, $rdfs->label );
		my $uri		= $graph->literal_value;
		my $return	= 0;
		if ($data) {
			try {
				warn "expected result data file: " . $data->uri_value . "\n" if ($debug);
				RDF::Trine::Parser->parse_url_into_model( $data->uri_value, $expected_model, context => RDF::Trine::Node::Resource->new($uri), canonicalize => 1 );
			} catch Error with {
				my $e	= shift;
				fail($test->as_string);
				earl_fail_test( $earl, $test, $e->text );
				print "# died: " . $test->as_string . ": $e\n";
				$return	= 1;
			};
			return if ($return);
		}
	}
	
	my $ok	= 0;
	eval {
		my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', update => 1 } );
		unless ($query) {
			warn 'Query error: ' . RDF::Query->error;
			return;
		}
		$query->execute( $test_model );
		
		my $test_graph		= RDF::Trine::Graph->new( $test_model );
		my $expected_graph	= RDF::Trine::Graph->new( $expected_model );
		
		
		my $eq	= $test_graph->equals( $expected_graph );
		$ok	= is( $eq, 1, $test->as_string );
		unless ($ok) {
			warn $test_graph->error;
			warn $test_model->as_string;
			warn $expected_model->as_string;
		}
	};
	if ($ok) {
		earl_pass_test( $earl, $test );
	} else {
		fail($test->as_string);
		earl_fail_test( $earl, $test, $@ );
		print "# failed: " . $test->as_string . "\n";
	}
	
	print STDERR "ok\n" if ($debug);
}

sub query_eval_test {
	my $model		= shift;
	my $test		= shift;
	my $earl		= shift;
	
	my ($action)	= $model->objects( $test, $mf->action );
	my ($result)	= $model->objects( $test, $mf->result );
	my ($req)		= $model->objects( $test, $mf->requires );
	my ($approved)	= $model->objects( $test, $dawgt->approval );
	my ($queryd)	= $model->objects( $action, $rq->query );
	my ($data)		= $model->objects( $action, $rq->data );
	my @gdata		= $model->objects( $action, $rq->graphData );
	
	if ($STRICT_APPROVAL) {
		unless ($approved) {
			warn "- skipping test because it isn't approved\n" if ($debug);
			return;
		}
		if ($approved->equal($dawgt->NotClassified)) {
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
	my ($test_model)	= RDF::Trine::Model->temporary_model;
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
	} except {
		my $e	= shift;
		die $e->text;
	} otherwise {
		warn '*** failed to construct model';
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
				$q		=~ s/([\x{256}-\x{1000}])/'\x{' . sprintf('%x', ord($1)) . '}'/eg;
				warn $q;
			}
			print STDERR "getting actual results... " if ($debug);
			my ($actual, $type)		= get_actual_results( $test_model, $sparql, $base, @gdata );
			print STDERR "ok\n" if ($debug);
			
			print STDERR "getting expected results... " if ($debug);
			my $expected	= get_expected_results( $resfilename, $type );
			print STDERR "ok\n" if ($debug);
			
		#	warn "comparing results...";
			compare_results( $expected, $actual, $earl, $test->as_string, \$comment );
		};
		warn $@ if ($@);
		if ($ok) {
			earl_pass_test( $earl, $test );
		} else {
			earl_fail_test( $earl, $test, $comment );
			print "# failed: " . $test->as_string . "\n";
		}
	}
}


exit;

######################################################################


sub add_to_model {
	my $model	= shift;
	my @files	= @_;
	
	foreach my $file (@files) {
		try {
			RDF::Trine::Parser->parse_url_into_model( $file, $model, canonicalize => 1 );
		} catch Error with {
			my $e	= shift;
			warn "Failed to load $file into model: " . $e->text;
		};
	}
}

sub get_actual_results {
	my $model	= shift;
	my $sparql	= shift;
	my $base	= shift;
	my @gdata	= @_;
	my $query	= RDF::Query->new( $sparql, { base => $base, lang => 'sparql11', load_data => 1 } );
	
	unless ($query) {
		warn RDF::Query->error if ($debug or $PATTERN);
		return;
	}
	
	my $testns	= RDF::Trine::Namespace->new('http://example.com/test-results#');
	my $rmodel	= RDF::Trine::Model->temporary_model;
	my $results	= $query->execute_with_named_graphs( $model, \@gdata );	# strict_errors => 1
	if ($args{ results }) {
		$results	= $results->materialize;
		warn "Got actual results:\n";
		warn $results->as_string;
	}
	if ($results->is_bindings) {
		return (binding_results_data( $results ), 'bindings');
	} elsif ($results->is_boolean) {
		$rmodel->add_statement( statement( $testns->result, $testns->boolean, literal(($results->get_boolean ? 'true' : 'false'), undef, $xsd->boolean) ) );
		return ($rmodel->get_statements, 'boolean');
	} elsif ($results->is_graph) {
		return ($results, 'graph');
	} else {
		warn "unknown result type: " . Dumper($results);
	}
}

sub get_expected_results {
	my $file		= shift;
	my $type		= shift;
	
	my $testns	= RDF::Trine::Namespace->new('http://example.com/test-results#');
	if ($type eq 'graph') {
		my $model	= RDF::Trine::Model->temporary_model;
		RDF::Trine::Parser->parse_url_into_model( "file://$file", $model, canonicalize => 1 );
		my $stream	= $model->get_statements();
		return $stream;
	} elsif ($file =~ /[.](srj|json)/) {
		my $model	= RDF::Trine::Model->temporary_model;
		my $data	= do { local($/) = undef; open(my $fh, '<', $file) or die $!; binmode($fh, ':utf8'); <$fh> };
		my $results	= RDF::Trine::Iterator->from_json( $data, { canonicalize => 1 } );
		if ($results->isa('RDF::Trine::Iterator::Boolean')) {
			$model->add_statement( statement( $testns->result, $testns->boolean, literal(($results->next ? 'true' : 'false'), undef, $xsd->boolean) ) );
			return $model->get_statements;
		} else {
			if ($args{ results }) {
				$results	= $results->materialize;
				warn "Got expected results:\n";
				warn $results->as_string;
			}
			return binding_results_data( $results );
		}
	} elsif ($file =~ /[.]srx/) {
		my $model	= RDF::Trine::Model->temporary_model;
		my $data	= do { local($/) = undef; open(my $fh, '<', $file) or die $!; binmode($fh, ':utf8'); <$fh> };
		my $results	= RDF::Trine::Iterator->from_string( $data, { canonicalize => 1 } );
		if ($results->isa('RDF::Trine::Iterator::Boolean')) {
			$model->add_statement( statement( $testns->result, $testns->boolean, literal(($results->next ? 'true' : 'false'), undef, $xsd->boolean) ) );
			return $model->get_statements;
		} else {
			if ($args{ results }) {
				$results	= $results->materialize;
				warn "Got expected results:\n";
				warn $results->as_string;
			}
			return binding_results_data( $results );
		}
	} else {
		die;
	}
}

sub compare_results {
	my $expected	= shift;
	my $actual		= shift;
	my $earl		= shift;
	my $test		= shift;
	my $comment		= shift || do { my $foo; \$foo };
	my $TODO		= shift;
	if (not(ref($actual))) {
		my $ok	= is( $actual, $expected, $test );
		return $ok;
	} elsif (blessed($actual) and $actual->isa('RDF::Trine::Iterator::Graph')) {
		die unless (blessed($expected) and $expected->isa('RDF::Trine::Iterator::Graph'));
		
		my $act_graph	= RDF::Trine::Graph->new( $actual );
		my $exp_graph	= RDF::Trine::Graph->new( $expected );
		
#  		local($debug)	= 1 if ($PATTERN);
		if ($debug) {
			warn ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n";
			my $actualxml		= $act_graph->get_statements->as_string;
			warn $actualxml;
			warn "-------------------------------\n";
			my $expectxml		= $exp_graph->get_statements->as_string;
			warn $expectxml;
			warn "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n";
		}
		my $eq	= $act_graph->equals( $exp_graph );
		unless ($eq) {
			warn $act_graph->error;
		}
		return is( $eq, 1, $test );
	} elsif (reftype($actual) eq 'HASH') {
		my @aresults	= @{ $actual->{ results } };
		my @eresults	= @{ $expected->{ results } };
		my $acount		= scalar(@aresults);
		my $ecount		= scalar(@eresults);
		if ($acount != $ecount) {
			warn "Result count ($acount) didn't match expected ($ecount)" if ($debug);
			return fail($test);
		}
		
# 		warn Data::Dumper->Dump([\@aresults, \@eresults], [qw(actual expected)]);
		
		my ($awith, $awithout)	= split_results_with_blank_nodes( @aresults );
		my ($ewith, $ewithout)	= split_results_with_blank_nodes( @eresults );

		# for the results without blanks, just serialize, sort, and compare
		my @astrings	= sort map { result_to_string($_) } @$awithout;
		my @estrings	= sort map { result_to_string($_) } @$ewithout;
		
		if ($actual->{ blanks } == 0 and $expected->{ blanks } == 0) {
			return is_deeply( \@astrings, \@estrings, $test );
		} elsif (join("\xFF", @astrings) ne join("\xFF", @estrings)) {
			warn "triples don't match: " . Dumper(\@astrings, \@estrings);
			fail($test);
		}
		
		# compare the results with bnodes
		my @ka	= keys %{ $actual->{blank_identifiers} };
		my @kb	= keys %{ $expected->{blank_identifiers} };
		my @kbp	= permute( @kb );
		MAPPING: foreach my $mapping (@kbp) {
			my %mapping;
			@mapping{ @ka }	= @$mapping;
			warn "trying mapping: " . Dumper(\%mapping) if ($debug);
			
			my %ewith	= map { result_to_string($_) => 1 } @$ewith;
			foreach my $row (@$awith) {
				my %row;
				foreach my $k (keys %$row) {
					my $n	= $row->{ $k };
					next unless (blessed($n));
					if ($n->isa('RDF::Trine::Node::Blank')) {
						my $id	= $mapping{ $n->blank_identifier };
						warn "mapping " . $n->blank_identifier . " to $id\n" if ($debug);
						$row{ $k }	= RDF::Trine::Node::Blank->new( $id );
					} else {
						$row{ $k }	= $n;
					}
				}
				my $mapped_row	= result_to_string( RDF::Query::VariableBindings->new( \%row ) );
				warn "checking for '$mapped_row' in " . Dumper(\%ewith) if ($debug);
				if ($ewith{ $mapped_row }) {
					delete $ewith{ $mapped_row };
				} else {
					next MAPPING;
				}
			}
			warn "found mapping: " . Dumper(\%mapping) if ($debug);
			return pass($test);
		}
	
		warn "failed to find bnode mapping: " . Dumper($awith, $ewith);
		return fail($test);
	} else {
		die Dumper($actual, $expected);
	}
}

sub binding_results_data {
	my $iter	= shift;
	my %data	= (results => [], blank_identifiers => {});
	while (my $row = $iter->next) {
		push(@{ $data{ results } }, $row );
		foreach my $key (keys %$row) {
			my $node	= $row->{$key};
			if (blessed($node) and $node->isa('RDF::Trine::Node::Blank')) {
				$data{ blank_identifiers }{ $node->blank_identifier }++;
			}
		}
	}
	$data{ blanks }	= scalar(@{ [ keys %{ $data{ blank_identifiers } } ] });
	return \%data;
}

sub split_results_with_blank_nodes {
	my (@with, @without);
	ROW: foreach my $row (@_) {
		my @keys	= grep { ref($row->{ $_ }) } keys %$row;
		foreach my $k (@keys) {
			my $node	= $row->{ $k };
			if (blessed($node) and $node->isa('RDF::Trine::Node::Blank')) {
				push(@with, $row);
				next ROW;
			}
		}
		push(@without, $row);
	}
	return (\@with, \@without);
}

sub result_to_string {
	my $row		= shift;
	my @keys	= grep { ref($row->{ $_ }) } keys %$row;
	my @results;
	foreach my $k (@keys) {
		my $node	= $row->{ $k };
		if ($node->isa('RDF::Trine::Node::Literal') and $node->has_datatype) {
			my $value	= RDF::Trine::Node::Literal->canonicalize_literal_value( $node->literal_value, $node->literal_datatype );
			$node		= RDF::Query::Node::Literal->new( $value, undef, $node->literal_datatype );
		}
		push(@results, join('=', $k, $node->as_string));
	}
	return join(',', sort(@results));
}
