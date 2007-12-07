package RDF::Endpoint;

use strict;
use warnings;

use RDF::Query;
use Data::Dumper;
use RDF::Store::DBI;
use List::Util qw(first);

sub new {
	my $class		= shift;
	my @args		= @_;
	my $self		= bless( {}, $class );
	my $store		= RDF::Store::DBI->new( @args );
	$self->{_store}	= $store;
	return $self;
}

sub handle_admin_post {
	my $self	= shift;
	my $cgi		= shift;
	my $port	= $self->port;
	my $host	= $self->host;
	warn 1;
	my $fh		= $cgi->upload('file');
	warn 2;
	my $data	= do { local($/) = undef; <$fh> };
	warn "RDF DATA:\n---------------------\n$data\n-----------------------\n";
	$self->redir(302, 'Found', "http://${host}:${port}/admin/index.html");
}

sub admin_index {
	my $self	= shift;
	my $cgi		= shift;
	my $store	= $self->{_store};
	my $html	= read_file( './docs/admin/index.html' );
	
	my $files	= qq[<table class="fileTable">\n]
				. qq[\t<tr><th>Source</th><th>Statements</th></tr>\n];
	my $stream	= $store->get_contexts;
	while (my $c = $stream->next) {
		my $uri		= $c->as_string;
		my $count	= $store->count_statements( undef, undef, undef, $c );
		$files		.= qq[\t<tr>] . join('', map { "<td>" . _html_escape($_) . "</td>" } ($uri, $count)) . qq[</tr>\n];
	}
	$files		.= qq[</table>\n];
	$html		=~ s/<[?]files[?]>/$files/se;
	
	print "HTTP/1.1 200 OK\nContent-Type: text/html; charset=utf-8\n\n";
	print $html;
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
		print "<html><head><title>SPARQL Results</title>\n";
		print <<"END";
			<style type="text/css">
				table {
					border: 1px solid #000;
					border-collapse: collapse;
				}
				
				th { background-color: #ddd; }
				td, th {
					padding: 1px 5px 1px 5px;
					border: 1px solid #000;
				}
			</style>
END
		print "</head><body>\n";
		print "<table>\n<tr>\n";
		
		my @names	= $stream->binding_names;
		my $columns	= scalar(@names);
		foreach my $name (@names) {
			print "\t<th>" . $name . "</th>\n";
		}
		print "</tr>\n";
		
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			print "<tr>\n";
			foreach my $k (@names) {
				my $value	= $bridge->as_string( $row->{ $k } );
				$value		=~ s/&/&amp;/g;
				$value		=~ s/</&lt;/g;
				print "\t<td>" . $value . "</td>\n";
			}
			print "</tr>\n";
		}
		print qq[<tr><th colspan="$columns">Total: $count</th></tr>];
		print "</table>\n";
		print "</body></html>\n";
	} else {
	
	}
}

sub _html_escape {
	my $text	= shift;
	for ($text) {
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/'/&apos;/g;
		s/"/&quot;/g;
	}
	return $text;
}

sub error {
	my $self	= shift;
	my $code	= shift;
	my $name	= shift;
	my $error	= shift;
	print "HTTP/1.1 ${code} ${name}\n\n<html><head><title>${name}</title></head><body><h1>${name}</h1><p>${error}</p></body></html>";
	return;
}

sub redir {
	my $self	= shift;
	my $code	= shift;
	my $message	= shift;
	my $url		= shift;
	print "HTTP/1.1 ${code} ${message}\nLocation: ${url}\n\n";
}

1;

__END__
