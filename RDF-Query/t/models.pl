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
	
	if (not $ENV{RDFQUERY_NO_RDFTRINE}) {
		eval "use RDF::Query::Model::RDFTrine;";
		if (not $@) {
			require RDF::Query::Model::RDFTrine;
			
			my ($model, $dsn, $user, $pass);
			if ($ENV{RDFQUERY_DBI_DATABASE} and $ENV{RDFQUERY_DBI_USER} and $ENV{RDFQUERY_DBI_PASS}) {
				$dsn	= "DBI:mysql:database=$ENV{RDFQUERY_DBI_DATABASE}";
				$user	= $ENV{RDFQUERY_DBI_USER} || 'test';
				$pass	= $ENV{RDFQUERY_DBI_PASS} || 'test';
				
				$model	= eval {
					my $store	= RDF::Trine::Store::DBI->temporary_store($dsn, $user, $pass);
					$model	= RDF::Trine::Model->new( $store );
				};
			} else {
				$model	= eval {
					my $store	= RDF::Trine::Store::DBI->temporary_store();
					$model	= RDF::Trine::Model->new( $store );
				}
			}
			if (not $@) {
				foreach my $i (0 .. $#files) {
					my $file	= $files[ $i ];
					my $uri		= $uris[ $i ];
					RDF::Trine::Parser->parse_url_into_model( $uri, $model );
				}
				
				my $bridge	= RDF::Query::Model::RDFTrine->new( $model );
				my $data	= $bridge->meta;
				$data->{ bridge }	= $bridge;
				$data->{ modelobj }	= $model;
				push(@models, $data);
			} else {
				warn "Couldn't connect to database: $dsn, $user, $pass" if ($RDF::Query::debug);
			}
		} else {
			warn "RDF::Trine::Store::DBI not loaded: $@\n" if ($RDF::Query::debug);
		}
	}
	
# 	if (not $ENV{RDFQUERY_NO_RDFTRINE}) {
# 		eval "use RDF::Query::Model::RDFTrine; use RDF::Trine::Store::Hexastore;";
# 		if (not $@) {
# 			require RDF::Query::Model::RDFTrine;
# 			require RDF::Trine::Store::Hexastore;
# 			
# 			my ($model, $dsn, $user, $pass);
# 			my $store	= RDF::Trine::Store::Hexastore->new();
# 			$model	= RDF::Trine::Model->new( $store );
# 			my $parser	= RDF::Trine::Parser->new('rdfxml');
# 			foreach my $i (0 .. $#files) {
# 				my $file	= $files[ $i ];
# 				my $uri		= $uris[ $i ];
# 				my $content	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
# 				$parser->parse_into_model( $uri, $content, $model );
# 			}
# 			my $bridge	= RDF::Query::Model::RDFTrine->new( $model );
# 			my $data	= $bridge->meta;
# 			$data->{ bridge }	= $bridge;
# 			$data->{ modelobj }	= $model;
# 			push(@models, $data);
# 		} else {
# 			warn "RDF::Trine::Store::Hexastore not loaded: $@\n" if ($RDF::Query::debug);
# 		}
# 	}

	if (not $ENV{RDFQUERY_NO_REDLAND}) {
		eval "use RDF::Query::Model::Redland;";
		if (not $@) {
			require RDF::Query::Model::Redland;
			my @data	= map { RDF::Redland::URI->new( "$_" ) } @uris;
			my $storage	= new RDF::Redland::Storage("hashes", "test", "new='yes',hash-type='memory',contexts='yes'");
			my $model	= new RDF::Redland::Model($storage, "");
			foreach (@data) {
				my $parser	= new RDF::Redland::Parser("guess");
				$parser->parse_into_model($_, $_, $model);
			}
			my $bridge	= RDF::Query::Model::Redland->new( $model );
			my $data	= $bridge->meta;
			$data->{ bridge }	= $bridge;
			$data->{ modelobj }	= $model;
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
			my $data	= $bridge->meta;
			$data->{ bridge }	= $bridge;
			$data->{ modelobj }	= $model;
			push(@models, $data);
		} else {
			warn "RDF::Core not loaded: $@\n" if ($RDF::Query::debug);
		}
	}
	
	############################################################################
	
	return @models;
}

1;
