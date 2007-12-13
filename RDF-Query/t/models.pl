#!/usr/bin/perl

use strict;
use warnings;

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
	
	if (not $ENV{RDFQUERY_NO_RDFBASE}) {
		eval "use RDF::Query::Model::RDFBase;";
		if (not $@) {
			require RDF::Query::Model::RDFBase;
			my $s		= new RDF::Base::Storage::DBI;
			my $model	= new RDF::Base::Model ( storage => $s );
			my $parser	= RDF::Base::Parser->new( name => 'rdfxml' );
			my @data	= @uris;
			foreach my $uri (@data) {
				$parser->parse_into_model($uri, $uri, $model);
			}
			
			my $bridge	= RDF::Query::Model::RDFBase->new( $model );
			my $data	= {
							bridge		=> $bridge,
							modelobj	=> $model,
							class		=> 'RDF::Query::Model::RDFBase',
							model		=> 'RDF::Base::Model',
							statement	=> 'RDF::Base::Statement',
							node		=> 'RDF::Base::Node',
							resource	=> 'RDF::Base::Node::Resource',
							literal		=> 'RDF::Base::Node::Literal',
							blank		=> 'RDF::Base::Node::Blank',
						};
			push(@models, $data);
		} else {
			warn "RDF::Base not loaded: $@\n" if ($RDF::Query::debug);
		}
	}
	
	if (not $ENV{RDFQUERY_NO_RDFSTORE}) {
		eval "use RDF::Query::Model::RDFStoreDBI;";
		if (not $@) {
			require RDF::Query::Model::RDFStoreDBI;
			my $model	= RDF::Store::DBI->temporary_store('DBI:mysql:database=test', 'test', 'test');
			
			{
				eval "use RDF::Redland";
				my @data	= map { RDF::Redland::URI->new( "$_" ) } @uris;
				my $storage	= RDF::Redland::Storage->new("mysql", $model->model_name, { host => 'localhost', database=> 'test', user => 'test', password => 'test' });
				my $model	= RDF::Redland::Model->new($storage, "");
				my $parser	= RDF::Redland::Parser->new("rdfxml");
				$parser->parse_into_model($_, $_, $model) for (@data);
			}
			
			my $bridge	= RDF::Query::Model::RDFStoreDBI->new( $model );
			my $data	= {
							bridge		=> $bridge,
							modelobj	=> $model,
							class		=> 'RDF::Query::Model::RDFStoreDBI',
							model		=> 'RDF::Store::DBI',
							statement	=> 'RDF::Query::Algebra::Triple',
							node		=> 'RDF::Query::Node',
							resource	=> 'RDF::Query::Node::Resource',
							literal		=> 'RDF::Query::Node::Literal',
							blank		=> 'RDF::Query::Node::Blank',
						};
			push(@models, $data);
		} else {
			warn "RDF::Store::DBI not loaded: $@\n";# if ($RDF::Query::debug);
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
