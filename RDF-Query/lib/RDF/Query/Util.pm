# RDF::Query::Util
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Util - Miscellaneous utility functions to support work with RDF::Query.

=head1 VERSION

This document describes RDF::Query::Util version 2.910.

=head1 SYNOPSIS

 use RDF::Query::Util;
 my $query = &RDF::Query::Util::cli_make_query;
 my $model = &RDF::Query::Util::cli_make_model;
 $query->execute( $model );
 ...

=head1 FUNCTIONS

=over 4

=cut

package RDF::Query::Util;

use strict;
use warnings;
no warnings 'redefine';
use Carp qw(carp croak confess);

use URI::file;
use RDF::Query;
use LWP::Simple;
use File::Spec;
use JSON;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

our $PREFIXES	= <<"END";
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX air: <http://www.daml.org/2001/10/html/airport-ont#>
PREFIX bibtex: <http://purl.oclc.org/NET/nknouf/ns/bibtex#>
PREFIX bio: <http://purl.org/vocab/bio/0.1/>
PREFIX book: <http://purl.org/net/schemas/book/>
PREFIX contact: <http://www.w3.org/2000/10/swap/pim/contact#>
PREFIX cyc: <http://www.cyc.com/2004/06/04/cyc#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX ical: <http://www.w3.org/2002/12/cal/icaltzd#>
PREFIX lang: <http://purl.org/net/inkel/rdf/schemas/lang/1.1#>
PREFIX likes: <http://rdf.netalleynetworks.com/ilike/20040830#>
PREFIX quaff: <http://purl.org/net/schemas/quaffing/>
PREFIX rel: <http://purl.org/vocab/relationship/>
PREFIX trust: <http://trust.mindswap.org/ont/trust.owl#>
PREFIX visit: <http://purl.org/net/vocab/2004/07/visit#>
PREFIX whois: <http://www.kanzaki.com/ns/whois#>
PREFIX wn: <http://xmlns.com/wordnet/1.6/>
PREFIX wot: <http://xmlns.com/wot/0.1/>
END

{
	my $file	= File::Spec->catfile($ENV{HOME}, '.prefix-cmd', 'prefixes.json');
	if (-r $file) {
		my $json		= do { local($/) = undef; open( my $fh, '<', $file ) or next; <$fh> };
		my $prefixes	= from_json($json);
		$PREFIXES	= join("\n", map { "PREFIX $_: <" . $prefixes->{$_} . ">" } (keys %$prefixes));
	}
}

=item C<< cli_make_query_and_model >>

Returns a query object, model, and args HASHref based on the arguments in @ARGV.
These arguments are parsed using C<< cli_make_query >> and C<< make_model >>.

=cut

sub cli_make_query_and_model {
	my ($query, $args)	= cli_make_query();
	my $model			= make_model( $args, @ARGV );
	return ($query, $model, $args);
}

=item C<< cli_make_query >>

Returns a RDF::Query object based on the arguments in @ARGV. These arguments
are parsed using C<< &cli_parse_args >>. If the -e flag is not present, the
query will be loaded from a file named by the argument in @ARGV immediately
following the final argument parsed by C<< &cli_parse_args >>.

=cut

sub cli_make_query {
	my %args	= cli_parse_args(@_);
	my $class	= delete $args{ class } || 'RDF::Query';
	my $sparql	= delete $args{ query };
	my $l		= Log::Log4perl->get_logger("rdf.query.util");
	$l->debug("creating sparql query with class $class");
	my $query	= $class->new( $sparql, \%args );
	
	if (wantarray) {
		return ($query, \%args);
	} else {
		return $query;
	}
}

=item C<< cli_make_model >>

Calls C<< make_model >> with arguments from C<< @ARGV >>, returning the
constructed model object.

C<< cli_make_model >> will usually be called after cli_make_query, allowing a
typical CLI invocation to look like `prog.pl [flags] [query file] [data files]`.

=cut

sub cli_make_model {
	my %args;
	my @files;
	while (scalar(@ARGV) and $ARGV[0] ne '--') {
		while (scalar(@ARGV) and $ARGV[0] =~ /^-(\w)$/) {
			my $opt	= shift(@ARGV);
			if ($opt eq '-s') {
				my $server	= shift(@ARGV);
				if ($server eq 'mysql') {
					$args{ dsn }	= "DBI:mysql:database=";
				} elsif ($server eq 'sqlite') {
					$args{ dsn }	= "DBI:SQLite:dbname=";
				} elsif ($server eq 'pg') {
					$args{ dsn }	= "DBI:Pg:dbname=";
				}
			} elsif ($opt eq '-d') {
				$args{ dbname }	= shift(@ARGV);
			} elsif ($opt eq '-u') {
				$args{ user }	= shift(@ARGV);
			} elsif ($opt eq '-p') {
				$args{ pass }	= shift(@ARGV);
			} elsif ($opt eq '-m') {
				$args{ model }	= shift(@ARGV);
			} elsif ($opt eq '--') {
				last;
			}
		}
		if (@ARGV) {
			my $file	= shift(@ARGV);
			push(@files, $file);
		}
	}
	if (scalar(@ARGV) and $ARGV[0] eq '--') {
		shift(@ARGV);
	}
	
	return make_model( \%args, @files );
}

=item C<< make_model ( @files ) >>

Returns a model object suitable for use in a call to C<< $query->execute >>,
loaded with RDF from files and/or URLs listed in @files. This model may be any
of the supported models, but as currently implemented will be a
RDF::Trine::Model object.

=cut

sub make_model {
	my $args	= shift;
	my %args	= %$args;
	my $l		= Log::Log4perl->get_logger("rdf.query.util");
	
	while (scalar(@_) and $_[0] =~ m/^-(.)/) {
		shift;
	}
	
	if ($args{ dsn } and $args{ user } and $args{ pass } and $args{ model } and $args{ dbname }) {
		$args{ dsn }		.= $args{ dbname };
		my $store	= RDF::Trine::Store::DBI->new($args{ model }, $args{ dsn }, $args{ user }, $args{ pass });
		my $model	= RDF::Trine::Model->new($store);
		return $model;
	} else {
		# create a temporary triplestore, and wrap it into a model
		my $model	= RDF::Trine::Model->temporary_model;
		
		# read in the list of files with RDF/XML content for querying
		my @files	= @_;
		
		# loop over all the files
		foreach my $i (0 .. $#files) {
			my $file	= $files[ $i ];
			my $pclass	= RDF::Trine::Parser->guess_parser_by_filename( $file ) || 'RDF::Trine::Parser::RDFXML';
			my $parser	= $pclass->new();
			
			if ($file =~ m<^https?:\/\/>) {
				$l->debug("fetching RDF from $file ...");
				$parser->parse_url_into_model( $file, $model );
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
}

=item C<< cli_parse_args >>

Parses CLI arguments from @ARGV and returns a HASH with the recognized key/values.
The allowable arguments are listed below.

=cut

sub cli_parse_args {
	my %args	= @_;
	$args{ class }	= 'RDF::Query';
	my @service_descriptions;
	
	while (scalar(@ARGV) and $ARGV[0] =~ /^-(\w+)/) {
		my $opt	= shift(@ARGV);
		if ($opt eq '-e') {
			$args{ query }	= shift(@ARGV);
		} elsif ($opt eq '-l') {
			$args{ lang }	= shift(@ARGV);
		} elsif ($opt eq '-O') {
			$args{ optimize }	= 1;
		} elsif ($opt eq '-o') {
			$args{ force_no_optimization }	= 1;
		} elsif ($opt eq '-k') {
			$args{ canonicalize }	= 1;
		} elsif ($opt eq '-C') {
			my $k	= shift(@ARGV);
			my $v	= shift(@ARGV);
			$args{ $k }	= $v;
		} elsif ($opt eq '-c') {
			my $class		= shift(@ARGV);
			eval "require $class";
			$args{ class }	= $class;
		} elsif ($opt eq '-f') {
			require RDF::Query::Federate;
			$args{ class }	= 'RDF::Query::Federate';
		} elsif ($opt eq '-F') {
			require RDF::Query::Federate;
			require RDF::Query::ServiceDescription;
			$args{ class }	= 'RDF::Query::Federate';
			my $url_string	= shift(@ARGV);
			my $uri;
			if ($url_string =~ m<^https?:\/\/>) {
				$uri		= URI->new( $url_string );
			} else {
				$uri		= URI::file->new_abs( $url_string );
			}
			my $sd	= RDF::Query::ServiceDescription->new_from_uri( $uri );
			push(@service_descriptions, $sd);
		} elsif ($opt eq '-E') {
			require RDF::Query::Federate;
			require RDF::Query::ServiceDescription;
			$args{ class }	= 'RDF::Query::Federate';
			my $service_url	= shift(@ARGV);
			my $sd	= RDF::Query::ServiceDescription->new( $service_url );
			push(@service_descriptions, $sd);
		} elsif ($opt =~ /^-D([^=]+)(=(.+))?/) {
			$args{ defines }{ $1 }	= (defined($2) ? $3 : 1);
		} elsif ($opt eq '-N') {
			$args{ declare_namespaces }	= 1;
		} elsif ($opt eq '-s') {
			my $server	= shift(@ARGV);
			if ($server eq 'mysql') {
				$args{ dsn }	= "DBI:mysql:database=";
			} elsif ($server eq 'sqlite') {
				$args{ dsn }	= "DBI:SQLite:dbname=";
			} elsif ($server eq 'pg') {
				$args{ dsn }	= "DBI:Pg:dbname=";
			}
		} elsif ($opt eq '-d') {
			$args{ dbname }	= shift(@ARGV);
		} elsif ($opt eq '-u') {
			$args{ user }	= shift(@ARGV);
		} elsif ($opt eq '-p') {
			$args{ pass }	= shift(@ARGV);
		} elsif ($opt eq '-m') {
			$args{ model }	= shift(@ARGV);
		} elsif ($opt eq '-w') {
			if (exists($args{update}) and not($args{update})) {
				warn "Model requested to be both read-only and read-write.\n";
			} else {
				$args{ update }	= 1;
			}
		} elsif ($opt eq '-r') {
			if (exists($args{update}) and $args{update}) {
				warn "Model requested to be both read-only and read-write.\n";
			} else {
				$args{ update }	= 0;
			}
		} elsif ($opt eq '--') {
			last;
		}
	}
	
	if (@service_descriptions) {
		$args{ service_descriptions }	= \@service_descriptions;
	}
	
	unless (defined($args{query})) {
		if (@ARGV) {
			my $file	= shift(@ARGV);
			my $sparql	= ($file eq '-')
						? do { local($/) = undef; <> }
						: do { local($/) = undef; open(my $fh, '<', $file) || croak $!; binmode($fh, ':utf8'); <$fh> };
			$args{ query }	= $sparql;
		}
	}
	
	if ($args{ query }) {
		if (delete $args{ declare_namespaces }) {
			$args{ query }	= join('', $PREFIXES, $args{ query } );
		}
	}
	
	return %args;
}

=item C<< start_endpoint ( $model, $port ) >>

Starts an SPARQL endpoint HTTP server on port $port.

If called in list context, returns the PID and the actual port the server bound
to. If called in scalar context, returns only the port.

=cut

sub start_endpoint {
	my $model	= shift;
	my $port	= shift;
	my $path	= shift;
	
	require CGI;
	require RDF::Endpoint::Server;
	
	local($ENV{TMPDIR})	= '/tmp';
	my $cgi	= CGI->new;
	my $s	= RDF::Endpoint::Server->new_with_model( $model,
				Port		=> $port,
				Prefix		=> '',
				CGI			=> $cgi,
				IncludePath	=> $path,
			);
	
	my $pid	= $s->background();
#	warn "Endpoint started as [$pid]\n";
	if (wantarray) {
		return ($pid, $port);
	} else {
		return $port;
	}
}

1;

__END__

=back

=head1 COMMAND LINE ARGUMENTS

=over 4

=item -e I<str>

Specifies the query string I<str>.

=item -l I<lang>

Specifies the query language I<lang> used. This should be one of: B<sparql>,
B<sparql11>, or B<rdql>.

=item -O

Turns on optimization.

=item -o

Turns off optimization.

=item -c I<class>

Specifies the perl I<class> used to construct the query object. Defaults to
C<< RDF::Query >>.

=item -f

Implies -c B<RDF::Query::Federate>.

=item -F I<loc>

Specifies the URL or path to a file I<loc> which contains an RDF service
description. The described service is used as an underlying triplestore for
query answering. Implies -f.

=item -E I<url>

Specifies the URL of a remove SPARQL endpoint to be used as a data source. The
endpoint is used as an underlying triplestore for query answering. Implies -f.

=item -s I<database-type>

Specifies the database type to use for the underlying data model.

=item -u I<user>

=item -p I<password>

=item -m I<model>

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
