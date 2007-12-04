package RDF::Endpoint;

use strict;
use warnings;

use RDF::Query;
use Data::Dumper;
use RDF::Store::DBI;
use List::Util qw(first);
use base qw(HTTP::Server::Simple::CGI HTTP::Server::Simple::Static);

sub new {
	my $class		= shift;
	my $self		= $class->SUPER::new( @_ );
	my $store		= RDF::Store::DBI->new('endpoint', 'DBI:mysql:database=test', 'test', 'test');
	$self->{_store}	= $store;
	return $self;
}

sub handle_request {
	my $self	= shift;
	my $cgi		= shift;
	binmode( \*STDOUT, ':utf8' );
	
	my $port	= $self->port;
	my $host	= $self->host;
	my $path	= $ENV{REQUEST_URI};
	my $prefix	= "http://${host}:${port}";
	my $url		= $prefix . $path;
	
	if ($path =~ qr'^/sparql') {
		my $sparql	= $cgi->param('query');
		if ($sparql) {
			$self->run_query( $cgi, $sparql );
		} else {
			$self->error( 400, 'Bad Request', 'No query.' );
		}
	} else {
		if ($path =~ qr</$>) {
			my $url	= "${prefix}${path}index.html";
			print "HTTP/1.1 303 See Other\nLocation: ${url}\n\n";
		} elsif ($path =~ qr[^/admin/]) {
			$self->error( 403, 'Forbidden', 'You do not have permission to access this resource' );
			# do admin stuff here
		} else {
			unless ($self->serve_static($cgi, "./docs")) {
				$self->error( 404, 'Not Found', 'The requested resource could not be found' );
			}
		}
	}
}

sub run_query {
	my $self	= shift;
	my $cgi		= shift;
	my $sparql	= shift;
	my $store	= $self->{_store};
	my @accept	= map { $_->[0] }
					sort { $b->[1] <=> $a->[1] }
						map { my ($t,$q) = split(/;q=/, $_); $q ||= 1; [ $t,$q ] }
							sort { index($b, 'html') }
								split(',', $ENV{HTTP_ACCEPT});
	my %ok		= map { $_ => 1 } qw(text/plain text/xml application/rdf+xml application/json text/html application/xhtml+xml);
	my @types	= grep { exists($ok{ $_ }) } @accept;
	
	my $query	= RDF::Query->new( $sparql );
	unless ($query) {
		my $error	= RDF::Query->error;
		return $self->error( 400, 'Bad Request', $error );
	}
	my $stream	= $query->execute( $store );
	if ($stream) {
		my $type	= first {
						(/xml/)
							? 1
							: (/json/)
								? do { ($stream->isa('RDF::SPARQLResults::Graph')) ? 0 : 1 }
								: 1
					} @types;
		if (defined($type)) {
			if ($type =~ /html/) {
				print "HTTP/1.1 200 OK\nContent-Type: text/html; charset=utf-8\n\n";
				$self->stream_as_html( $stream );
			} elsif ($type =~ /xml/) {
				print "HTTP/1.1 200 OK\nContent-Type: ${type}; charset=utf-8\n\n";
				print $stream->as_xml;
			} elsif ($type =~ /json/) {
				print "HTTP/1.1 200 OK\nContent-Type: application/json; charset=utf-8\n\n";
				print $stream->as_json;
			} else {
				print "HTTP/1.1 200 OK\nContent-Type: text/plain; charset=utf-8\n\n";
				print $stream->as_xml;
			}
		} else {
			return $self->error( 406, 'Not Acceptable', 'No acceptable result encoding was found matching the request' );
		}
	} else {
		my $error	= RDF::Query->error;
		return $self->error( 400, 'Bad Request', $error );
	}
}

sub stream_as_html {
	my $self	= shift;
	my $stream	= shift;
	my $bridge	= $stream->bridge;
	
	if ($stream->isa('RDF::SPARQLResults::Graph')) {
		print "<html><head><title>SPARQL Results</title></head><body>\n";
		print "</body></html>\n";
	} elsif ($stream->isa('RDF::SPARQLResults::Boolean')) {
		print "<html><head><title>SPARQL Results</title></head><body>\n";
		print (($stream->get_boolean) ? "True" : "False");
		print "</body></html>\n";
	} elsif ($stream->isa('RDF::SPARQLResults::Bindings')) {
		print "<html><head><title>SPARQL Results</title></head><body>\n";
		print "<table>\n<tr>\n";
		foreach my $name ($stream->binding_names) {
			print "\t<th>" . $name . "</th>\n";
		}
		print "</tr>\n";
		
		while (my $row = $stream->next) {
			print "<tr>\n";
			foreach my $v (@$row) {
				my $value	= $bridge->as_string( $v );
				$value		=~ s/&/&amp;/g;
				$value		=~ s/</&lt;/g;
				print "\t<td>" . $value . "</td>\n";
			}
			print "</tr>\n";
		}
		print "</table>\n";
		print "</body></html>\n";
	} else {
	
	}
}

sub error {
	my $self	= shift;
	my $code	= shift;
	my $name	= shift;
	my $error	= shift;
	print "HTTP/1.1 ${code} ${name}\n\n<html><head><title>${name}</title></head><body><h1>${name}</h1><p>${error}</p></body></html>";
	return;
}

1;

__END__
