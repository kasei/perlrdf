#!/usr/bin/perl

use strict;
use warnings;
no warnings 'redefine';

use RDF::Query;
use File::Spec;
use URI::file;

sub test_models {
	my @models	= test_models_and_classes( @_ );
	return map { $_->{ 'modelobj' } } @models;
}

sub test_models_and_classes {
	my @files	= map { File::Spec->rel2abs( $_ ) } @_;
	my @uris	= map { URI::file->new_abs( $_ ) } @files;
	my @models;
	
	if (not $ENV{RDFQUERY_NO_REDLAND}) {
		eval "use RDF::Query::Model::Redland;";
		if (not $@) {
			require RDF::Query::Model::Redland;
			my @data	= map { RDF::Redland::URI->new( "$_" ) } @uris;
			my $storage	= new RDF::Redland::Storage("hashes", "test", "new='yes',hash-type='memory',contexts='yes'");
			my $model	= new RDF::Redland::Model($storage, "");
			my $parser	= new RDF::Redland::Parser("rdfxml");
			$parser->parse_into_model($_, $_, $model) for (@data);
			my $bridge	= RDF::Query::Model::Redland->new( $model );
			
			my $data	= {
							bridge		=> $bridge,
							modelobj	=> $model,
							class		=> 'RDF::Query::Model::Redland',
							model		=> 'RDF::Redland::Model',
							statement	=> 'RDF::Redland::Statement',
							node		=> 'RDF::Redland::Node',
							resource	=> 'RDF::Redland::Node',
							literal		=> 'RDF::Redland::Node',
							blank		=> 'RDF::Redland::Node',
						};
			push(@models, $data);
		} else {
			warn "RDF::Redland not loaded: $@\n" if ($RDF::Query::debug);
		}
	}
	
	if (not $ENV{RDFQUERY_NO_RDFCORE}) {
		eval "use RDF::Query::Model::RDFCore;";
		if (not $@) {
			require RDF::Query::Model::RDFCore;
			my $storage	= new RDF::Core::Storage::Memory;
			my $model	= new RDF::Core::Model (Storage => $storage);
			my $counter	= 0;
			foreach my $file (@files) {
				my $prefix	= 'r' . $counter++ . 'a';
				my $parser	= new RDF::Core::Model::Parser (
								Model		=> $model,
								Source		=> $file,
								SourceType	=> 'file',
								BaseURI		=> 'http://example.com/',
								BNodePrefix	=> $prefix,
							);
				$parser->parse;
			}
			my $bridge	= RDF::Query::Model::RDFCore->new( $model );
			my $data	= {
							bridge		=> $bridge,
							modelobj	=> $model,
							class		=> 'RDF::Query::Model::RDFCore',
							model		=> 'RDF::Core::Model',
							statement	=> 'RDF::Core::Statement',
							node		=> 'RDF::Core::Node',
							resource	=> 'RDF::Core::Resource',
							literal		=> 'RDF::Core::Literal',
							blank		=> 'RDF::Core::Node',
						};
			push(@models, $data);
		} else {
			warn "RDF::Core not loaded: $@\n" if ($RDF::Query::debug);
		}
	}
	
	if (not $ENV{RDFQUERY_NO_RDFTRINE}) {
		eval "use RDF::Query::Model::RDFTrine;";
		if (not $@) {
			require RDF::Query::Model::RDFTrine;
			
			if ($ENV{RDFQUERY_DBI_DATABASE} and $ENV{RDFQUERY_DBI_USER} and $ENV{RDFQUERY_DBI_PASS}) {
				my $dsn		= "DBI:mysql:database=$ENV{RDFQUERY_DBI_DATABASE}";
				my $user	= $ENV{RDFQUERY_DBI_USER} || 'test';
				my $pass	= $ENV{RDFQUERY_DBI_PASS} || 'test';
				
				my $model	= eval {
					my $store	= RDF::Trine::Store::DBI->temporary_store($dsn, $user, $pass);
					my $model	= RDF::Trine::Model->new( $store );
				};
				if (not $@) {
					{
						eval "use RDF::Redland";
						if ($@) {
							warn "RDF::Redland is currently needed to parse RDF/XML for RDF::Trine::Store";
							return @models;
						}
						my @data	= map { RDF::Redland::URI->new( "$_" ) } @uris;
						my $storage	= RDF::Redland::Storage->new("mysql", $model->_store->model_name, { host => 'localhost', database=> $ENV{RDFQUERY_DBI_DATABASE}, user => $ENV{RDFQUERY_DBI_USER}, password => $ENV{RDFQUERY_DBI_PASS} });
						my $model	= RDF::Redland::Model->new($storage, "");
						my $parser	= RDF::Redland::Parser->new("rdfxml");
						$parser->parse_into_model($_, $_, $model) for (@data);
					}
					
					my $bridge	= RDF::Query::Model::RDFTrine->new( $model );
					my $data	= {
									bridge		=> $bridge,
									modelobj	=> $model,
									class		=> 'RDF::Query::Model::RDFTrine',
									model		=> 'RDF::Trine::Store::DBI',
									statement	=> 'RDF::Trine::Statement',
									node		=> 'RDF::Trine::Node',
									resource	=> 'RDF::Trine::Node::Resource',
									literal		=> 'RDF::Trine::Node::Literal',
									blank		=> 'RDF::Trine::Node::Blank',
								};
					push(@models, $data);
				} else {
					warn "Couldn't connect to mysql: $dsn, $user, $pass" if ($RDF::Query::debug);
				}
			} else {
				warn "RDF::Trine::Store::DBI not used. To use, set the environment variables RDFQUERY_DBI_DATABASE, RDFQUERY_DBI_USER and RDFQUERY_DBI_PASS." if ($RDF::Query::debug);
			}
		} else {
			warn "RDF::Trine::Store::DBI not loaded: $@\n" if ($RDF::Query::debug);
		}
	}
	
	############################################################################
	if (0) {
		require RDF::Query::Model::RDFCore;
		require RDF::Core::Storage::Mysql;
		my $dbh		= Kasei::Common::dbh();
		my $storage	= new RDF::Core::Storage::Mysql ( dbh => $dbh, Model => 'db1' );
		my $model	= new RDF::Core::Model (Storage => $storage);
		if ($storage and $model) {
			my $data	= {
							bridge	=> $model,
						};
			push(@models, $data);
		}
	}
	if (0) {
		require RDF::Query::Model::RDFCore;
		require RDF::Core::Storage::Mysql;
		my $dbh		= Kasei::Common::dbh();
		my $storage	= new RDF::Core::Storage::Mysql ( dbh => $dbh, Model => 'db1' );
		my $model	= new RDF::Core::Model (Storage => $storage);
		if ($storage and $model) {
			my $data	= {
							bridge	=> $model,
						};
			push(@models, $data);
		}
	}
	############################################################################
	
	return @models;
}

1;
