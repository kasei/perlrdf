package RDF::Query::Util;

use strict;
use warnings;
no warnings 'redefine';
use Carp qw(carp croak confess);

use RDF::Query;
use LWP::Simple;

sub cli_make_query {
	my %args	= cli_parse_args();
	my $class	= delete $args{ class };
	my $sparql	= delete $args{ query };
	my $l		= Log::Log4perl->get_logger("rdf.query.util");
	$l->debug("creating sparql query with class $class");
	return $class->new( $sparql, \%args );
}

sub cli_parse_args {
	my %args;
	$args{ class }	= 'RDF::Query';
	
	return unless (@ARGV);
	while ($ARGV[0] =~ /^-(\w+)$/) {
		my $opt	= shift(@ARGV);
		if ($opt eq '-e') {
			$args{ query }	= shift(@ARGV);
		} elsif ($opt eq '-l') {
			$args{ lang }	= shift(@ARGV);
		} elsif ($opt eq '-o') {
			$args{ optimize }	= 1;
		} elsif ($opt eq '-c') {
			my $class		= shift(@ARGV);
			eval "require $class";
			$args{ class }	= $class;
		} elsif ($opt eq '-f') {
			require RDF::Query::Federate;
			$args{ class }	= 'RDF::Query::Federate';
		}
	}
	
	unless (defined($args{query})) {
		my $file	= shift(@ARGV);
		my $sparql	= ($file eq '-')
					? do { local($/) = undef; <> }
					: do { local($/) = undef; open(my $fh, '<', $file) || die $!; binmode($fh, ':utf8'); <$fh> };
		$args{ query }	= $sparql;
	}
	return %args;
}

sub cli_get_query {
	my %args	= cli_parse_args();
	return $args{ query };
}

sub cli_make_model {
	my $l		= Log::Log4perl->get_logger("rdf.query.util");
	
	# create a temporary triplestore, and wrap it into a model
	my $store	= RDF::Trine::Store::DBI->temporary_store();
	my $model	= RDF::Trine::Model->new( $store );
	
	# read in the list of files with RDF/XML content for querying
	my @files	= @ARGV;
	
	# create a rdf/xml parser object that we'll use to read in the rdf data
	my $parser	= RDF::Trine::Parser->new('rdfxml');
	
	# loop over all the files
	foreach my $i (0 .. $#files) {
		my $file	= $files[ $i ];
		if ($file =~ m<^https?:\/\/>) {
			$l->debug("fetching RDF from $file ...");
			my $uri		= URI->new( $file );
			my $content	= get($file);
			$parser->parse_into_model( $uri, $content, $model );
		} else {
			$file	= File::Spec->rel2abs( $file );
			# $uri is the URI object used as the base uri for parsing
			my $uri		= URI::file->new_abs( $file );
			my $content	= do { open( my $fh, '<', $file ); local($/) = undef; <$fh> };
			$parser->parse_into_model( $uri, $content, $model );
		}
	}
	return $model;
}

1;
