#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use Encode qw(encode);

use URI::file;
use Test::More;
use File::Temp qw(tempfile);
use Scalar::Util qw(blessed reftype);

use RDF::Query;
use RDF::Query::Node qw(iri);
use RDF::Trine;
use RDF::Trine::Graph;
use RDF::Trine::Namespace qw(rdf);
use RDF::Trine::Iterator qw(smap);

use RDF::Core;
use RDF::Query::Model::RDFCore;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.trine.parser		= TRACE, Screen
# 	log4perl.appender.Screen				= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr			= 0
# 	log4perl.appender.Screen.layout			= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

our $debug			= 0;
our $debug_results	= 0;
if ($] < 5.007003) {
	plan skip_all => 'perl >= 5.7.3 required';
	exit;
}

if ($ENV{RDFQUERY_DAWGTEST}) {
#	plan qw(no_plan);
} else {
	plan skip_all => 'Developer tests. Set RDFQUERY_DAWGTEST to run these tests.';
	exit;
}

use Data::Dumper;
use XML::Simple;

plan qw(no_plan);
require "t/dawg/earl.pl";
	
my $PATTERN		= shift(@ARGV) || '';
my $BNODE_RE	= qr/^(r|genid)[0-9A-F]+[r0-9]*$/;

no warnings 'once';
$RDF::Query::Model::RDFCore::USE_RAPPER	= 1;

if ($PATTERN) {
	$debug_results	= 1;
}

warn "PATTERN: ${PATTERN}\n" if ($PATTERN and $debug);

my @manifests;
my ($bridge, $model)	= new_model( glob( "t/dawg/data-r2/manifest-evaluation.ttl" ) );
print "# Using model object from " . ref($model) . "\n";

{
	my $ns		= RDF::Trine::Namespace->new('http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#');
	my $inc		= $ns->include;
	my $st		= $bridge->new_statement( undef, $inc, undef );
	my $stream	= $bridge->get_statements( undef, $inc, undef );
	my $statement	= $stream->next();
	
	if ($statement) {
		my $list		= $statement->object;
		my $first		= $rdf->first;
		my $rest		= $rdf->rest;
		while ($list and not $list->equal( $rdf->nil )) {
			my $value			= get_first_obj( $bridge, $list, $first );
			$list				= get_first_obj( $bridge, $list, $rest );
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
	add_to_model( $bridge, @manifests );
}

my $earl	= init_earl( $bridge );
my $type	= $bridge->new_resource( "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" );
my $evalt	= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#QueryEvaluationTest" );
my $mfname	= $bridge->new_resource( "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#name" );

{
	print "# Evaluation Tests\n";
	my $stream	= $bridge->get_statements( undef, $type, $evalt );
	while (my $statement = $stream->next()) {
		my $test		= $statement->subject;
		my $name		= get_first_literal( $bridge, $test, $mfname );
		unless ($bridge->uri_value( $test ) =~ /$PATTERN/) {
			next;
		}
		warn "### eval test: " . $test->as_string . " >>> " . $name . "\n" if ($debug);
		eval_test( $bridge, $test, $earl );
	}
}

unless ($PATTERN) {
	open( my $fh, '>', 'earl-eval.ttl' ) or die $!;
	print {$fh} earl_output( $earl );
	close($fh);
}

################################################################################

sub eval_test {
	my $bridge		= shift;
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
	
	my $action		= get_first_obj( $bridge, $test, $mfact );
	my $result		= get_first_obj( $bridge, $test, $mfres );
	my $req			= get_first_obj( $bridge, $test, $reqs );
	my $approved	= get_first_obj( $bridge, $test, $approval );
	my $queryd		= get_first_obj( $bridge, $action, $qtquery );
	my $data		= get_first_obj( $bridge, $action, $qtdata );
	my @gdata		= get_all_obj( $bridge, $action, $qtgdata );
	return unless ($approved);
	
	my $uri					= URI->new( $bridge->uri_value( $queryd ) );
	my $filename			= $uri->file;
	my (undef,$base,undef)	= File::Spec->splitpath( $filename );
	$base					= "file://${base}";
	my $sparql				= do { local($/) = undef; open(my $fh, '<', $filename); binmode($fh, ':utf8'); <$fh> };
	
	my $q			= $sparql;
	$q				=~ s/\s+/ /g;
	if ($debug) {
		warn "### test     : " . $bridge->as_string( $test ) . "\n";
		warn "# sparql     : $q\n";
		warn "# data       : " . $bridge->as_string( $data ) if (blessed($data));
		warn "# graph data : " . $bridge->as_string( $_ ) for (@gdata);
		warn "# result     : " . $bridge->as_string( $result );
		warn "# requires   : " . $bridge->as_string( $req ) if (blessed($req));
	}
	
	print STDERR "constructing model... " if ($debug);
	my ($test_bridge, $test_model)	= new_model();
	if (blessed($data)) {
		add_to_model( $test_bridge, $bridge->uri_value( $data ) );
	}
	print STDERR "ok\n" if ($debug);
	
	my $resuri		= URI->new( $bridge->uri_value( $result ) );
	my $resfilename	= $resuri->file;
	
	TODO: {
		local($TODO)	= (blessed($req)) ? "requires " . $bridge->as_string( $req ) : '';
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
			my $ok			= compare_results( $expected, $actual, $earl, $bridge->as_string( $test ), $TODO );
		};
		warn $@ if ($@);
		if ($ok) {
			earl_pass_test( $earl, $test );
		} else {
			earl_fail_test( $earl, $test );
			print "# failed: " . $bridge->as_string( $test ) . "\n";
# 			die;	 # XXX
		}
	}
}


exit;

######################################################################


sub new_model {
	my @files		= @_;
	my $store		= RDF::Trine::Store::DBI->temporary_store;
	my $model		= RDF::Trine::Model->new( $store );
	my $bridge		= RDF::Query::Model::RDFTrine->new( $model );
# 	my $bridge		= RDF::Query->new_bridge();
	add_to_model( $bridge, file_uris(@files) );
	return ($bridge, $bridge->model);
}

sub add_to_model {
	my $bridge	= shift;
	my @files	= @_;
	
	if ($bridge->isa('RDF::Query::Model::RDFCore')) {
		foreach my $file (@files) {
			Carp::cluck unless ($file);
			if ($file =~ /^http:/) {
				$file	=~ s{^http://www.w3.org/2001/sw/DataAccess/tests/}{t/dawg/data-r2/};
				$file	= 'file://' . File::Spec->rel2abs( $file );
			}
			my $data	= ($file =~ /[.]rdf/)
						? do {
								$file	=~ s#^file://##;
								open(my $fh, '<', $file);
								local($/)	= undef;
								<$fh>
							}
						: do {
#								open(my $fh, '-|', "cwm.py --n3 $file --rdf");
								open(my $fh, '-|', "rapper -q -i turtle -o rdfxml $file");
								local($/)	= undef;
								<$fh>
							};
			
			$data		=~ s/^(.*)<rdf:RDF/<rdf:RDF/m;
#			warn "---------------------\n$data---------------------\n";
			$bridge->add_string( $data, $file );
		}
	} else {
		foreach my $file (@files) {
			$bridge->add_uri( $file );
		}
	}
}

sub add_to_model_named {
	my $model	= shift;
	my $bridge	= RDF::Query->get_bridge( $model );
	my @files	= @_;
	foreach my $uri (@files) {
		$bridge->add_uri( "$uri", 1 );
	}
	return 1;
}

sub add_source_to_model {
	my $model	= shift;
	my @sources	= @_;
	if ($bridge->isa('RDF::Query::Model::RDFCore')) {
		foreach my $data (@sources) {
# 			my $data	= do {
# 							open(my $fh, '-|', "cwm.py --n3 $file --rdf");
# 							local($/)	= undef;
# 							<$fh>
# 						};
# 			
# 			$data		=~ s/^(.*)<rdf:RDF/<rdf:RDF/m;
# 			$bridge->ignore_contexts;
# #			warn "---------------------\n$data---------------------\n";
			$bridge->add_string( $data, 'http://kasei.us/ns#' );
		}
	} else {
		foreach my $source (@sources) {
			$bridge->add_string( $source, 'http://kasei.us/ns#' );
		}
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
	my $query	= RDF::Query->new( $sparql, $base, undef, 'sparql11' );
	
	local($RDF::Query::Model::Redland::debug)	= 1 if ($debug);
	local($RDF::Query::Model::RDFCore::debug)	= 1 if ($debug);
	local($RDF::Query::Model::RDFTrine::debug)	= 1 if ($debug);
	
	return unless $query;
	
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
		my ($bridge, $model)	= new_model( $file );
		my $stream	= $bridge->get_statements();
		return $stream;
	} elsif ($file =~ /[.]srx/) {
		my $data		= do { local($/) = undef; open(my $fh, '<', $file) or die $!; binmode($fh, ':utf8'); <$fh> };
		my $xml			= XMLin( $file );
		
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
								my $value	= $binding->{literal}{content} || '';
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
		my ($bridge, $model)	= new_model( $file );
		my $p_type		= iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
		my $p_rv		= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#resultVariable');
		my $p_solution	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#solution');
		my $p_binding	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#binding');
		my $p_boolean	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#boolean');
		my $p_value		= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#value');
		my $p_variable	= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#variable');
		my $t_rs		= iri('http://www.w3.org/2001/sw/DataAccess/tests/result-set#ResultSet');
		my $rss			= smap { $bridge->subject($_) } $bridge->get_statements( undef, $p_type, $t_rs );
		my $rs			= $rss->next;
		
		if (my $bool = get_first_as_string( $bridge, $rs, $p_boolean )) {
			return $bool;
		} else {
			my $vnodess		= smap { $bridge->literal_value( $bridge->object($_) ) } $bridge->get_statements( $rs, $p_rv, undef );
			my @vars		= $vnodess->get_all();
			my $rowss		= smap { $bridge->object($_) } $bridge->get_statements( $rs, $p_solution, undef );
			
			my @results;
			while (my $row = $rowss->next) {
				my %data;
				my $stream		= smap { $bridge->object( $_ ) } $bridge->get_statements( $row, $p_binding, undef );
				my @bindings	= $stream->get_all();
#				my @bindings	= $model->targets( $row, $p_binding );
				foreach my $b (@bindings) {
					my $var		= get_first_as_string( $bridge, $b, $p_variable );
					my $value	= get_first_as_string( $bridge, $b, $p_value );
					$data{ $var }	= $value;
				}
				push(@results, \%data);
			}
			return \@results;
		}
	}
}

sub model_to_arrayref {
	my $bridge	= shift;
	my @data;
	my $stream	= $bridge->get_statements();
	{
		my %bnode_map;
		while(my $statement = $stream->next) {
			my $s			= $bridge->subject( $statement );
			my $p			= $bridge->predicate( $statement );
			my $o			= $bridge->object( $statement );
			my @triple;
			foreach my $node ($s, $p, $o) {
				if ($bridge->isa_blank( $node )) {
					my $id		= $bridge->blank_identifier( $node );
					unless (exists( $bnode_map{ $id } )) {
						my $blank			= [];
						$bnode_map{ $id }	= $blank;
					}
					push( @triple, $bnode_map{ $id } );
				} elsif ($bridge->isa_resource( $node )) {
					push( @triple, $bridge->uri_value( $node ) );
				} else {
					push( @triple, node_as_string( $node ) );
				}
			}
			push(@data, \@triple);
		} continue {
			$stream->next;
		}
	}
	return \@data;
}

sub compare_results {
	my $expected	= shift;
	my $actual		= shift;
	my $earl		= shift;
	my $test		= shift;
	my $TODO		= shift;
	warn 'compare_results: ' . Data::Dumper->Dump([$expected, $actual], [qw(expected actual)]) if ($debug or $debug_results);
	
	
	if (not(ref($actual))) {
		my $ok	= is( $actual, $expected, $test );
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
					fail( "$test: expected but didn't find: " . join(', ', @{ $row }{ @keys }) );
					return 0;
				}
			}
		}
		
		my @remaining	= keys %actual_flat;
		warn "remaining: " . Data::Dumper::Dumper(\@remaining) if ($debug and (@remaining));
		return is( scalar(@remaining), 0, "$test: no unchecked results" );
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
	return $node ? $bridge->uri_value( $node ) : undef;
}

sub get_all_uri {
	my @nodes	= get_all_obj( @_ );
	return map { $bridge->uri_value($_) } grep { defined($_) and $bridge->isa_resource($_) } @nodes;
}

sub get_first_obj {
	my $bridge	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : $bridge->new_resource( $_ ) } @uris;
	foreach my $pred (@preds) {
		my $stream	= $bridge->get_statements( $node, $pred, undef );
		my $targets	= smap { $bridge->object( $_ ) } $stream;
		while (my $node = $targets->next) {
			return $node if ($node);
		}
	}
}

sub get_all_obj {
	my $bridge	= shift;
	my $node	= shift;
	my $uri		= shift;
	my @uris	= UNIVERSAL::isa($uri, 'ARRAY') ? @{ $uri } : ($uri);
	my @preds	= map { ref($_) ? $_ : $bridge->new_resource( $_ ) } @uris;
	my @objs;
	
	my @streams;
	foreach my $pred (@preds) {
		push(@streams, $bridge->get_statements( $node, $pred, undef ));
	}
	my $stream	= shift(@streams);
	while (@streams) {
		$stream	= $stream->concat( shift(@streams) );
	}
	my $targets	= smap { $bridge->object( $_ ) } $stream;
	return $targets->get_all();
}

sub relativeize_url {
	my $uri	= shift;
	if ($uri =~ /^http:/) {
		$uri	=~ s{^http://www.w3.org/2001/sw/DataAccess/tests/}{t/dawg/data-r2/};
		$uri	= 'file://' . File::Spec->rel2abs( $uri );
	}
	return $uri;
}
