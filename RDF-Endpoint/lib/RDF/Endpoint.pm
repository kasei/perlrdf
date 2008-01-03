package RDF::Endpoint;

use strict;
use warnings;

our $VERSION;
BEGIN {
	$VERSION	= '1.000';
}

use Template;
use RDF::Query;
use File::Spec;
use File::Slurp;
use URI::Escape;
use Data::Dumper;
use LWP::UserAgent;
use RDF::Trine::Store::DBI;
use List::Util qw(first);

sub new {
	my $class		= shift;
	my $dsn			= shift;
	my $user		= shift;
	my $pass		= shift;
	my $model		= shift;
	my %args		= @_;
	
	my $incpath		= $args{ IncludePath } || './include';
	my $adminurl	= $args{ AdminURL };
	my $submiturl	= $args{ SubmitURL };
	
	my $self		= bless( { incpath => $incpath, admin => $adminurl, submit => $submiturl }, $class );
	my $store		= RDF::Trine::Store::DBI->new( $dsn, $user, $pass, $model );
	
	$self->{_store}	= $store;
	$self->{_ua}	= LWP::UserAgent->new;
	
	$self->{_ua}->agent( "RDF::Endpoint/${VERSION}" );
	$self->{_ua}->default_header( 'Accept' => 'application/turtle,application/x-turtle,application/rdf+xml' );
	
	my $template	= Template->new( {
						INCLUDE_PATH	=> $incpath,
					} );
	$self->{_tt}	= $template;
	return $self;
}

sub query_page {
	my $self	= shift;
	my $cgi		= shift;
	my $prefix	= shift;
	
	my $store	= $self->_store;
	my $tt		= $self->_template;
	my $file	= 'index.html';

	print $cgi->header( -type => 'text/html; charset=utf-8' );
	my $submit	= $self->submit_url;
	$tt->process( $file, { submit_url => $submit } ) || die $tt->error();
}

sub handle_admin_post {
	my $self	= shift;
	my $cgi		= shift;
	my $host	= shift;
	my $port	= shift;
	my $prefix	= shift;
	my $store		= $self->{_store};
	
	my @keys	= $cgi->param;
	foreach my $key (sort @keys) {
		if ($key eq 'add_uri') {
			my $url		= $cgi->param($key);
			$self->_add_uri( $url );
		} elsif ($key =~ /^delete_<(.*)>$/) {
			my $url	= $1;
			my $ctx	= RDF::Trine::Node::Resource->new( $url );
			$store->remove_statements( undef, undef, undef, $ctx );
		} elsif ($key =~ /^replace_<(.*)>$/) {
			my $url	= $1;
			my $ctx	= RDF::Trine::Node::Resource->new( $url );
#			$store->remove_statements( undef, undef, undef, $ctx );
			
			warn "REPLACE $url";
		}
		
	}
	use Data::Dumper;
	warn 'ADMIN POST: ' . Dumper( { $cgi->Vars } );
	my $method	= $cgi->request_method();
	
	$self->redir( $cgi, 302, "Found", $self->admin_url );
}

sub _add_uri {
	my $self	= shift;
	my $url		= shift;
	my $ua		= $self->_agent;
	my $resp	= $ua->get($url);
	my $store		= $self->{_store};
	if ($resp->is_success) {
		require RDF::Redland;
		my $data		= $resp->content;
		my $base		= $url;
		my $format		= 'guess';
		my $baseuri		= RDF::Redland::URI->new( $base );
		my $basenode	= RDF::Trine::Node::Resource->new( $base );
		my $parser		= RDF::Redland::Parser->new( $format );
		my $stream		= $parser->parse_string_as_stream( $data, $baseuri );
		while ($stream and !$stream->end) {
			my $statement	= $stream->current;
			my $stmt		= RDF::Trine::Statement->from_redland( $statement );
			$store->add_statement( $stmt, $basenode );
			$stream->next;
		}
	} else {
		die $resp->status_line;
	}
}

sub admin_index {
	my $self	= shift;
	my $cgi		= shift;
	my $prefix	= shift;
	
	my $store	= $self->_store;
	my $tt		= $self->_template;
	my $file	= 'admin_index.html';

	my @files;
	my $stream	= $store->get_contexts;
	while (my $c = $stream->next) {
		my $uri		= $c->as_string;
		my $count	= $store->count_statements( undef, undef, undef, $c );
		push( @files, {
			source			=> _html_escape($uri),
			count			=> $count,
			delete_field	=> $cgi->checkbox( -name => "delete_${uri}", -label => '', -checked => 0 ),
			replace_field	=> $cgi->filefield( -name => "replace_${uri}" ),
		} );
	}
	
	print $cgi->header( -type => 'text/html; charset=utf-8' );
	my $submit	= $self->admin_url;
	$tt->process( $file, { admin_submit_url => $submit, files => \@files } );
}

sub save_query {
	my $self	= shift;
	my $cgi		= shift;
	my $sparql	= shift;
	my $query	= RDF::Query->new( $sparql );
	my $serial	= $query->as_sparql;
	my $dbh		= $self->_store->dbh;
	
	my $sth		= $dbh->prepare( "SELECT Name FROM Queries WHERE Query = ?" );
	$sth->execute( $serial );
	my ($name)	= $sth->fetchrow;
	unless ($name) {
		$dbh->begin_work;
		my $sth		= $dbh->prepare( "SELECT MAX(Name) FROM Queries" );
		$sth->execute();
		my ($name)	= $sth->fetchrow;
		if ($name) {
			$name++;
		} else {
			$name	= 'a';
		}
		
		my $ins		= $dbh->prepare( "INSERT INTO Queries (Name, Query) VALUES (?,?)" );
		$ins->execute( $name, $serial );
		$dbh->commit;
	}
	return $name;
}

sub run_saved_query {
	my $self	= shift;
	my $cgi		= shift;
	my $name	= shift;

	my $dbh		= $self->_store->dbh;
	my $sth		= $dbh->prepare( "SELECT Query FROM Queries WHERE Name = ?" );
	$sth->execute( $name );
	my ($sparql)	= $sth->fetchrow;
	if ($sparql) {
		$self->run_query( $cgi, $sparql );
	} else {
		my $error	= 'Unrecognized query name';
		return $self->error( $cgi, 400, 'Bad Request', $error );
	}
}

sub run_query {
	my $self	= shift;
	my $cgi		= shift;
	my $sparql	= shift;
	$self->save_query( $cgi, $sparql );
	
	my $store		= $self->{_store};
	my $http_accept	= $ENV{HTTP_ACCEPT} || 'text/html';
	my @accept	= map { $_->[0] }
					sort { $b->[1] <=> $a->[1] }
						map { my ($t,$q) = split(/;q=/, $_); $q ||= 1; [ $t,$q ] }
							sort { index($b, 'html') }
								split(',', $http_accept);
	my %ok		= map { $_ => 1 } qw(text/plain text/xml application/rdf+xml application/json text/html application/xhtml+xml);
	if (my $t = $cgi->param('mime-type')) {
		unshift( @accept, $t );
	}
	my @types	= (grep { exists($ok{ $_ }) } @accept);
	
	my $query	= RDF::Query->new( $sparql );
	unless ($query) {
		my $error	= RDF::Query->error;
		return $self->error( $cgi, 400, 'Bad Request', $error );
	}
	my $stream	= $query->execute( $store );
	if ($stream) {
		my $tt		= $self->_template;
		my $file	= 'results.html';
		my $type	= first {
						(/xml/)
							? 1
							: (/json/)
								? do { ($stream->isa('RDF::SPARQLResults::Graph')) ? 0 : 1 }
								: 1
					} @types;
		if (defined($type)) {
			my $bridge	= $stream->bridge;
			if ($type =~ /html/) {
				print $cgi->header( -type => 'text/html; charset=utf-8' );
				my $total	= 0;
				my $rtype	= $stream->type;
				my $rstream	= ($rtype eq 'graph') ? $stream->unique() : $stream;
				$tt->process( $file, {
					result_type => $rtype,
					next_result => sub { my $r = $rstream->next_result; $total++ if ($r); return $r },
					columns		=> sub { $rstream->binding_names },
					values		=> sub { my $row = shift; my $col = shift; return _html_escape( $bridge->as_string( $row->{ $col } ) ) },
					boolean		=> sub { $rstream->get_boolean },
					nodes		=> sub { my $s = shift; return [ map { _html_escape( $bridge->as_string( $s->$_() ) ) } qw(subject predicate object) ]; },
					total		=> sub { $total },
					feed_url	=> $self->feed_url( $cgi ),
				} ) or warn $tt->error();
			} elsif ($type =~ /xml/) {
				print $cgi->header( -type => "$type; charset=utf-8" );
				print $stream->as_xml;
			} elsif ($type =~ /json/) {
				print $cgi->header( -type => "application/json; charset=utf-8" );
				print $stream->as_json;
			} else {
				print $cgi->header( -type => "text/plain; charset=utf-8" );
				print $stream->as_xml;
			}
			
		} else {
			return $self->error( $cgi, 406, 'Not Acceptable', 'No acceptable result encoding was found matching the request' );
		}
	} else {
		my $error	= RDF::Query->error;
		return $self->error( $cgi, 400, 'Bad Request', $error );
	}
}

sub feed_url {
	my $self	= shift;
	my $cgi		= shift;
	my @keys	= grep { $_ ne 'mime-type' } $cgi->param();
	my %args;
	foreach my $key ($cgi->param()) {
		$args{ $key }	= $cgi->param( $key );
	}
	$args{ 'mime-type' }	= 'application/rdf+xml';
	my $url		= '?' . join('&', map { join('=', uri_escape( $_ ), uri_escape( $args{ $_ } )) } (keys %args));
	return $url
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

sub admin_url {
	my $self	= shift;
	return $self->{admin};
}

sub submit_url {
	my $self	= shift;
	return $self->{submit};
}

sub _template {
	my $self	= shift;
	return $self->{_tt};
}

sub _agent {
	my $self	= shift;
	return $self->{_ua};
}

sub _store {
	my $self	= shift;
	return $self->{_store};
}

sub _html_escape {
	my $text	= shift || '';
	for ($text) {
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/'/&apos;/g;
		s/"/&quot;/g;
	}
	return $text;
}

sub init {
	my $self	= shift;
	my $store	= $self->_store;
	my $dbh		= $store->dbh;
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Queries (
            Name VARCHAR(8) UNIQUE NOT NULL,
            Query longtext NOT NULL
        );
END
	return 1;
}

sub error {
	my $self	= shift;
	my $cgi		= shift;
	my $code	= shift;
	my $name	= shift;
	my $error	= shift;
	print $cgi->header( -status => "${code} ${name}" );
	print "<html><head><title>${name}</title></head><body><h1>${name}</h1><p>${error}</p></body></html>";
	return;
}

sub redir {
	my $self	= shift;
	my $cgi		= shift;
	my $code	= shift;
	my $message	= shift;
	my $url		= shift;
	print $cgi->header( -status => "${code} ${message}", -Location => $url );
	return;
}

1;

__END__
