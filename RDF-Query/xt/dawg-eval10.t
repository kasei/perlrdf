#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'redefine';

use Encode qw(encode);

use URI::file;
use Test::More;
use File::Temp qw(tempfile);
use Scalar::Util qw(blessed reftype);
use Storable qw(dclone);
use Algorithm::Combinatorics qw(permutations);
use LWP::MediaTypes qw(add_type);
use Text::CSV_XS;
use Regexp::Common qw /URI/;

add_type( 'application/rdf+xml' => qw(rdf xrdf rdfx) );
add_type( 'text/turtle' => qw(ttl) );
add_type( 'text/plain' => qw(nt) );
add_type( 'text/x-nquads' => qw(nq) );
add_type( 'text/json' => qw(json) );
add_type( 'text/html' => qw(html xhtml htm) );

use RDF::Query;
use RDF::Query::Node qw(iri blank literal variable);
use RDF::Trine qw(statement);
use RDF::Trine::Error qw(:try);
use RDF::Trine::Graph;
use RDF::Trine::Namespace qw(rdf rdfs xsd);
use RDF::Trine::Iterator qw(smap);
use RDF::Endpoint 0.05;
use Carp;
use HTTP::Request;
use HTTP::Response;
use HTTP::Message::PSGI;

$RDF::Query::Plan::PLAN_CLASSES{'service'}	= 'Test::RDF::Query::Plan::Service';

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan.service		= TRACE, Screen
# # 	log4perl.category.rdf.query.plan.join.pushdownnestedloop		= TRACE, Screen
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
	if ($opt eq '-v') {
		$debug++;
	} elsif ($opt =~ /^-(.*)$/) {
		$args{ $1 }	= 1;
	} else {
		$PATTERN	= $opt;
	}
}

$ENV{RDFQUERY_THROW_ON_SERVICE}	= 1;

no warnings 'once';

if ($PATTERN) {
# 	$debug			= 1;
}

warn "PATTERN: ${PATTERN}\n" if ($PATTERN and $debug);

my $model		= RDF::Trine::Model->temporary_model;
my @manifests	= map { $_->as_string } map { URI::file->new_abs( $_ ) } map { glob( "xt/dawg/data-r2/$_/manifest.ttl" ) }
	qw(
		algebra
		ask
		basic
		bnode-coreference
		bound
		cast
		construct
		dataset
		distinct
		expr-builtin
		expr-equals
		expr-ops
		graph
		i18n
		open-world
		optional
		optional-filter
		reduced
		regex
		solution-seq
		sort
		triple-match
		type-promotion
	);
foreach my $file (@manifests) {
	warn "Parsing manifest $file\n" if $debug;
	RDF::Trine::Parser->parse_url_into_model( $file, $model, canonicalize => 1 );
}
warn "done parsing manifests" if $debug;

my $earl	= init_earl( $model );
my $rs		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/result-set#');
my $mf		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
my $ut		= RDF::Trine::Namespace->new('http://www.w3.org/2009/sparql/tests/test-update#');
my $rq		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-query#');
my $dawgt	= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-dawg#');

{
	my @manifests	= $model->subjects( $rdf->type, $mf->Manifest );
	foreach my $m (@manifests) {
		warn "Manifest: " . $m->as_string . "\n" if ($debug);
		my ($list)	= $model->objects( $m, $mf->entries );
		unless (blessed($list)) {
			warn "No mf:entries found for manifest " . $m->as_string . "\n";
		}
		my @tests	= $model->get_list( $list );
		foreach my $test (@tests) {
			my $et	= $model->count_statements($test, $rdf->type, $mf->QueryEvaluationTest);
			my $ct	= $model->count_statements($test, $rdf->type, $mf->CSVResultFormatTest);
			if ($et + $ct) {
				my ($name)	= $model->objects( $test, $mf->name );
				unless ($test->uri_value =~ /$PATTERN/) {
					next;
				}
				warn "### query eval test: " . $test->as_string . " >>> " . $name->literal_value . "\n" if ($debug);
				query_eval_test( $model, $test, $earl );
			}

			if ($model->count_statements($test, $rdf->type, $ut->UpdateEvaluationTest) or $model->count_statements($test, $rdf->type, $mf->UpdateEvaluationTest)) {
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

open( my $fh, '>', 'earl-eval-10.ttl' ) or die $!;
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
		warn "# data       : " . $data->as_string . "\n" if (blessed($data));
		warn "# graph data : " . $_->as_string . "\n" for (@gdata);
		warn "# result     : " . $result->as_string . "\n";
		warn "# requires   : " . $req->as_string . "\n" if (blessed($req));
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

	if ($debug) {
		warn "Dataset before update operation:\n";
		warn $test_model->as_string;
	}
	my $ok	= 0;
	eval {
		my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', update => 1, canonicalize => 1 } );
		unless ($query) {
			warn 'Query error: ' . RDF::Query->error;
			fail($test->as_string);
			return;
		}

		my ($plan, $ctx)	= $query->prepare( $test_model );
		$query->execute_plan( $plan, $ctx );

		my $test_graph		= RDF::Trine::Graph->new( $test_model );
		my $expected_graph	= RDF::Trine::Graph->new( $expected_model );


		my $eq	= $test_graph->equals( $expected_graph );
		$ok	= is( $eq, 1, $test->as_string );
		unless ($ok) {
			warn $test_graph->error;
			warn "Got model:\n" . $test_model->as_string;
			warn "Expected model:\n" . $expected_model->as_string;
		}
	};
	if ($@ or not($ok)) {
		if ($@) {
			fail($test->as_string);
		}
		earl_fail_test( $earl, $test, $@ );
		print "# failed: " . $test->as_string . "\n";
	} else {
		earl_pass_test( $earl, $test );
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
	my @sdata		= $model->objects( $action, $rq->serviceData );

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


# 	warn 'service data: ' . Dumper(\@sdata);
	foreach my $sd (@sdata) {
		my ($url)	= $model->objects( $sd, $rq->endpoint );
		print STDERR "setting up remote endpoint $url...\n" if ($debug);
		my ($data)		= $model->objects( $sd, $rq->data );
		my @gdata		= $model->objects( $sd, $rq->graphData );
		if ($debug) {
			warn "- data       : " . $data->as_string if (blessed($data));
			warn "- graph data : " . $_->as_string for (@gdata);
		}
		my $model		= RDF::Trine::Model->new();
		if ($data) {
			RDF::Trine::Parser->parse_url_into_model( $data->uri_value, $model );
		}
		$Test::RDF::Query::Plan::Service::service_ctx{ $url->uri_value }	= $model;
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
	my $model		= shift;
	my $sparql		= shift;
	my $base		= shift;
	my @gdata		= @_;
	my $query		= RDF::Query->new( $sparql, { base => $base, lang => 'sparql10', load_data => 1, canonicalize => 1 } );

	unless ($query) {
		warn RDF::Query->error if ($debug or $PATTERN);
		return;
	}

	my $testns	= RDF::Trine::Namespace->new('http://example.com/test-results#');
	my $rmodel	= RDF::Trine::Model->temporary_model;

	my ($plan, $ctx)	= $query->prepare_with_named_graphs( $model, @gdata );
	if ($args{plan}) {
		warn $plan->explain('  ', 0);
	}
	my $results			= $query->execute_plan( $plan, $ctx );
	if ($args{ results }) {
		$results	= $results->materialize;
		warn "Actual results:\n";
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
		my $results	= $model->get_statements();
		if ($args{ results }) {
			$results	= $results->materialize;
			warn "Expected results:\n";
			warn $results->as_string;
		}
		return $results;
	} elsif ($file =~ /[.](srj|json)/) {
		my $model	= RDF::Trine::Model->temporary_model;
		my $data	= do { local($/) = undef; open(my $fh, '<', $file) or die $!; binmode($fh, ':utf8'); <$fh> };
		my $results	= RDF::Trine::Iterator->from_json( $data, { canonicalize => 1 } );
		if ($results->isa('RDF::Trine::Iterator::Boolean')) {
			my $value	= $results->next;
			my $bool	= ($value ? 'true' : 'false');
			$model->add_statement( statement( $testns->result, $testns->boolean, literal($bool, undef, $xsd->boolean) ) );
			if ($args{ results }) {
				warn "Expected result: $bool\n";
			}
			return $model->get_statements;
		} else {
			if ($args{ results }) {
				$results	= $results->materialize;
				warn "Expected results:\n";
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
				warn "Expected results:\n";
				warn $results->as_string;
			}
			return binding_results_data( $results );
		}
	} elsif ($file =~ /[.]csv/) {
		my $csv	= Text::CSV_XS->new({binary => 1});
		open( my $fh, "<:encoding(utf8)", $file ) or die $!;
		my $header	= $csv->getline($fh);
		my @vars	= @$header;
		my @data;
		while (my $row = $csv->getline($fh)) {
			my %result;
			foreach my $i (0 .. $#vars) {
				my $var		= $vars[$i];
				my $value	= $row->[ $i ];
				# XXX @@ heuristics that won't always work.
				# XXX @@ expected to work on the test suite, though
				if ($value =~ /^_:(\w+)$/) {
					$value	= blank($1);
				} elsif ($value =~ /$RE{URI}/) {
					$value	= iri($value);
				} elsif (defined($value) and length($value)) {
					$value	= literal($value);
				}
				$result{ $var }	= $value;
			}
			push(@data, \%result);
		}
		if ($args{ results }) {
			warn "Expected results:\n";
			warn Dumper(\@data);
		}
		return \@data;
	} elsif ($file =~ /[.]tsv/) {
		open( my $fh, "<:encoding(utf8)", $file ) or die $!;
		my $header	= <$fh>;
		chomp($header);
		my @vars	= split("\t", $header);
		foreach (@vars) { s/[?]// }

		my @data;
		my $parser	= RDF::Trine::Parser::Turtle->new();
		while (defined(my $line = <$fh>)) {
			chomp($line);
			my $row	= [ split("\t", $line) ];
			my %result;
			foreach my $i (0 .. $#vars) {
				my $var		= $vars[$i];
				my $value	= $row->[ $i ];
				my $node	= length($value) ? $parser->parse_node( $value ) : undef;
				$result{ $var }	= $node;
			}

			push(@data, RDF::Query::VariableBindings->new( \%result ));
		}
		my $iter	= RDF::Trine::Iterator::Bindings->new(\@data);
		return binding_results_data($iter);
	} elsif ($file =~ /[.](ttl|rdf)/) {
		my $model	= RDF::Trine::Model->new();
		open( my $fh, "<:encoding(utf8)", $file ) or die $!;
		my $base	= 'file://' . File::Spec->rel2abs($file);
		my $parser	= RDF::Trine::Parser->new(($file =~ /[.]ttl/) ? 'turtle' : 'rdfxml');
		$parser->parse_file_into_model( $base, $file, $model );
		my ($res)	= $model->subjects( $rdf->type, $rs->ResultSet );
		if (my($b) = $model->objects( $res, $rs->boolean )) {
			my $bool	= $b->literal_value;
			my $rmodel	= RDF::Trine::Model->new();
			$rmodel->add_statement( statement( $testns->result, $testns->boolean, literal($bool, undef, $xsd->boolean) ) );
			if ($args{ results }) {
				warn "Expected result: $bool\n";
			}
			return $rmodel->get_statements;
		} else {
			my @vars	= $model->objects( $res, $rs->resultVariable );
			my @sols	= $model->objects( $res, $rs->solution );
			my @names	= map { $_->literal_value } @vars;
			my @bindings;
			foreach my $r (@sols) {
				my %data;
				my @b	= $model->objects( $r, $rs->binding );
				foreach my $b (@b) {
					my ($value)	= $model->objects( $b, $rs->value );
					my ($var)	= $model->objects( $b, $rs->variable );
					$data{ $var->literal_value }	= $value;
				}
				push(@bindings, RDF::Trine::VariableBindings->new( \%data ));
			}
			my $iter	= RDF::Trine::Iterator::Bindings->new( \@bindings, \@names );
			if ($args{ results }) {
				$iter	= $iter->materialize;
				warn "Got expected results:\n";
				warn $iter->as_string;
			}
			return binding_results_data($iter);
		}
	} else {
		die "Unrecognized type of expected results: $file";
	}
}

sub compare_results {
	my $expected	= shift;
	my $actual		= shift;
	my $earl		= shift;
	my $test		= shift;
	my $comment		= shift || do { my $foo; \$foo };
	my $TODO		= shift;



	my $lossy_cmp	= 0;
	if (reftype($expected) eq 'ARRAY') {
		# comparison with expected results coming from a lossy format like csv/tsv
		$lossy_cmp	= 1;
		my %data	= (results => [], blank_identifiers => {});
		foreach my $row (@$expected) {
			push(@{ $data{ results } }, $row );
			foreach my $key (keys %$row) {
				my $node	= $row->{$key};
				if (blessed($node) and $node->isa('RDF::Trine::Node::Blank')) {
					$data{ blank_identifiers }{ $node->blank_identifier }++;
				}
			}
		}
		$data{ blanks }	= scalar(@{ [ keys %{ $data{ blank_identifiers } } ] });
		$expected	= \%data;
	}

	if (not(ref($actual))) {
		my $ok	= is( $actual, $expected, $test );
		return $ok;
	} elsif (blessed($actual) and $actual->isa('RDF::Trine::Iterator::Graph')) {
		die "Unexpected Graph result type (was expecting " . ref($expected) . ")" unless (blessed($expected) and $expected->isa('RDF::Trine::Iterator::Graph'));

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
	} elsif (reftype($actual) eq 'HASH' and reftype($expected) eq 'HASH') {
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
		my @astrings	= sort map { result_to_string($_, $lossy_cmp) } @$awithout;
		my @estrings	= sort map { result_to_string($_, $lossy_cmp) } @$ewithout;

		if ($actual->{ blanks } == 0 and $expected->{ blanks } == 0) {
			return is_deeply( \@astrings, \@estrings, $test );
		} elsif (join("\xFF", @astrings) ne join("\xFF", @estrings)) {
			warn "triples don't match: " . Dumper(\@astrings, \@estrings);
			return fail($test);
		}

		# compare the results with bnodes
		my @ka	= keys %{ $actual->{blank_identifiers} };
		my @kb	= keys %{ $expected->{blank_identifiers} };

		my $kbp = permutations( \@kb );
		MAPPING: while (my $mapping = $kbp->next) {
			my %mapping;
			@mapping{ @ka }	= @$mapping;
			warn "trying mapping: " . Dumper(\%mapping) if ($debug);

			my %ewith	= map { result_to_string($_, $lossy_cmp) => 1 } @$ewith;
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
				my $mapped_row	= result_to_string( RDF::Query::VariableBindings->new( \%row ), $lossy_cmp );
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
		die "Failed to compare actual and expected results: " . Dumper($actual, $expected);
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
	my $row			= shift;
	my $lossy_cmp	= shift;
	my @keys		= grep { ref($row->{ $_ }) } keys %$row;
	my @results;

	foreach my $k (@keys) {
		my $node	= $row->{ $k };
		if ($node->isa('RDF::Trine::Node::Literal') and $node->has_datatype) {
			my ($value, $dt);
			if ($lossy_cmp) {
				$value	= $node->literal_value;
				$dt		= undef;
			} else {
				$value	= RDF::Trine::Node::Literal->canonicalize_literal_value( $node->literal_value, $node->literal_datatype );
				$dt		= $node->literal_datatype;
			}
			$node		= RDF::Query::Node::Literal->new( $value, undef, $dt );
		}
		push(@results, join('=', $k, $node->as_string));
	}
	return join(',', sort(@results));
}

package Test::RDF::Query::Plan::Service;

use strict;
use warnings;
use Data::Dumper;
use Scalar::Util qw(refaddr);
use base qw(RDF::Query::Plan::Service);

our %ENDPOINTS;
our %service_ctx;

sub new {
	my $class		= shift;
	my $endpoint	= shift;
	my $plan		= shift;
	my $silent		= shift;
	my $sparql		= shift;

	if ($endpoint->isa('RDF::Query::Node::Resource')) {
		my $uri			= $endpoint->uri_value;
		warn "setting up mock endpoint for $uri" if ($debug);
	}

	my $self	= $class->SUPER::new( $endpoint, $plan, $silent, $sparql, @_ );

	if ($endpoint->isa('RDF::Query::Node::Resource')) {
		my $uri			= $endpoint->uri_value;
		my $e			= URI->new($uri);
		my $model 		= $service_ctx{ $uri };
# 		warn "model for $uri: $model";
		if ($model) {
			my $end		= RDF::Endpoint->new( $model, { endpoint => { endpoint_path => $e->path } } );
			$ENDPOINTS{ refaddr($self) }	= $end;
		}
	}

	return $self;
}

# sub mock {
# 	my $self		= shift;
# 	return;
# 	my $endpoint	= shift;
# 	my $data		= shift;
# 	my $e			= URI->new($endpoint);
#
# 	my $model		= RDF::Trine::Model->new();
# 	my ($default, $named)	= @$data;
# 	if ($default) {
# 		RDF::Trine::Parser->parse_url_into_model( $default->uri_value, $model );
# 		my $end		= RDF::Endpoint->new( $model, { endpoint => { endpoint_path => $e->path } } );
# 		$ENDPOINTS{ refaddr($self) }	= $end;
# 	}
# }

sub _request {
	my $self	= shift;
	my $ua		= shift;
	my $req		= shift;
	my $env		= $req->to_psgi;
	my $end		= $ENDPOINTS{ refaddr($self) };
	if ($end) {
# 		warn "got mocked endpoint";
		my $app			= sub {
			my $env 	= shift;
			my $req 	= Plack::Request->new($env);
			my $resp	= $end->run( $req );
			return $resp->finalize;
		};
		my $data	= $app->( $env );
		my $resp	= HTTP::Response->from_psgi( $data );
		return $resp;
	} else {
# 		warn "no mocked endpoint available";
		return HTTP::Response->new(403);
	}
}

sub DESTROY {
	my $self	= shift;
	delete $ENDPOINTS{ refaddr($self) };
	$self->SUPER::DESTROY();
}
