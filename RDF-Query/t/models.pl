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
			my $parser	= RDF::Trine::Parser->new('rdfxml');
			my $handler	= sub { my $st	= shift; $model->add_statement( $st ) };
			foreach my $i (0 .. $#files) {
				my $file	= $files[ $i ];
				my $uri		= $uris[ $i ];
				my $content	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
				$parser->parse( $uri, $content, $handler );
			}
			my $data	= {
				statement	=> 'RDF::Query::Algebra::Triple',
				node		=> 'RDF::Trine::Node',
				resource	=> 'RDF::Trine::Node::Resource',
				literal		=> 'RDF::Trine::Node::Literal',
				blank		=> 'RDF::Trine::Node::Blank',
			};
			$data->{ modelobj }	= $model;
			push(@models, $data);
		} else {
			warn "Couldn't connect to database: $dsn, $user, $pass" if ($RDF::Query::debug);
		}
	}
	
	if (not $ENV{RDFQUERY_NO_REDLAND}) {
		my $storage	= new RDF::Redland::Storage("hashes", "test", "new='yes',hash-type='memory',contexts='yes'");
		my $model	= new RDF::Redland::Model($storage, "");
		my $tmodel	= RDF::Trine::Model->new( RDF::Trine::Store->new_with_object( $model ) );
		foreach my $uri (@uris) {
			RDF::Trine::Parser->parse_url_into_model( $uri, $tmodel );
		}
		my $data	= {
			model		=> 'RDF::Redland::Model',
			store		=> 'RDF::Redland::Storage',
			statement	=> 'RDF::Redland::Statement',
			node		=> 'RDF::Redland::Node',
			resource	=> 'RDF::Redland::Node',
			literal		=> 'RDF::Redland::Node',
			blank		=> 'RDF::Redland::Node',
		};
		$data->{ modelobj }	= $model;
		push(@models, $data);
	}
	
	return @models;
}

1;
