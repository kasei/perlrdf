package RDF::Endpoint;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'redefine';

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
use Net::OpenID::Consumer;

use List::Util qw(first);
use Scalar::Util qw(blessed);

use RDF::Trine::Store::DBI;
use RDF::Trine::Model::StatementFilter;

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
	my $whitelist	= $args{ WhiteListModel };
	
	my $wlstore		= RDF::Trine::Store::DBI->new( $whitelist, $dsn, $user, $pass );
	my $wlmodel		= RDF::Trine::Model->new( $wlstore );
	
	my $store		= RDF::Trine::Store::DBI->new( $model, $dsn, $user, $pass );
	my $m			= RDF::Trine::Model::StatementFilter->new( $store );
	my $self		= bless( {
						incpath		=> $incpath,
						admin		=> $adminurl,
						submit		=> $submiturl,
						whitelist	=> $wlmodel,
						_model		=> $m,
						_ua			=> LWP::UserAgent->new,
					}, $class );
	$self->_load_endpoint_config;
	
	if (my $id = $args{ Identity }) {
		$self->set_identity( $id );
	}
	
	if ($self->authorized_user) {
		$self->{_model}	= RDF::Trine::Model->new( $store );
	} else {
		$m->add_rule( sub {
			my $st	= shift;
			my $p	= $st->predicate;
			my $uri	= $p->uri_value;
			
			return 0 if ($uri eq 'http://xmlns.com/foaf/0.1/mbox');
			return 0 if ($uri eq 'http://xmlns.com/foaf/0.1/phone');
			return 0 if ($uri =~ m<^http://xmlns.com/foaf/0.1/\w+ChatID$>);
			return 1;
		} );
	}
	
	$self->{_ua}->agent( "RDF::Endpoint/${VERSION}" );
	$self->{_ua}->default_header( 'Accept' => 'application/turtle,application/x-turtle,application/rdf+xml' );
	
	my $template	= Template->new( {
						INCLUDE_PATH	=> $incpath,
					} );
	$self->{_tt}	= $template;
	return $self;
}

sub authorized_user {
	my $self	= shift;
	my $id		= $self->get_identity;
	return 0 unless ($id);
	
	our %authorized;
	if (exists $authorized{ $id }) {
		return $authorized{ $id };
	} else {
		my $wl		= $self->{ whitelist };
		my $sparql	= $self->auth_query( $id );
		my $query	= RDF::Query->new( $sparql );
		my $res		= $query->execute( $wl );
		if (blessed($res) and $res->get_boolean) {
			$authorized{ $id }	= 1;
			return 1;
		} else {
			$authorized{ $id }	= 0;
			return 0;
		}
	}
}

sub login_page {
	my $self	= shift;
	my $cgi		= shift;
	
	my $model	= $self->_model;
	my $tt		= $self->_template;
	my $file	= 'login.html';

	print $cgi->header( -type => 'text/html; charset=utf-8' );
	my $submit	= $self->submit_url;
	
	$tt->process( $file, {
					submit_url	=> $submit,
				} ) || die $tt->error();
}

sub query_page {
	my $self	= shift;
	my $cgi		= shift;
	my $prefix	= shift;
	
	my $model	= $self->_model;
	my $tt		= $self->_template;
	my $file	= 'index.html';

	print $cgi->header( -type => 'text/html; charset=utf-8' );
	my $submit	= $self->submit_url;
	
	my $login	= $self->_login_crumb;
	$tt->process( $file, {
					submit_url	=> $submit,
					login		=> $login,
				} ) || die $tt->error();
}

sub _login_crumb {
	my $self	= shift;
	my $submit	= $self->submit_url;
	if (my $id = $self->get_identity) {
		return qq<[Logged in as $id; <a href="${submit}?logout=1">Logout</a>.]>;
	} else {
		return qq<[<a href="${submit}?login=1">Login</a>]>;
	}
}

sub handle_admin_post {
	my $self	= shift;
	my $cgi		= shift;
	my $host	= shift;
	my $port	= shift;
	my $prefix	= shift;
	my $model	= $self->_model;
	
	my $owner	= $cgi->param( 'owner_openid' );
	if ($owner ne $self->owner_openid) {
		$self->set_owner_openid( $owner );
		return $self->redir( $cgi, 302, "Found", $self->submit_url );
	}
	
	my $preds		= $cgi->param('priv_preds');
	$self->update_priv_preds( $preds );
	
	my $auth		= $cgi->param('auth_query');
	$self->update_auth_query( $auth );

	$self->_load_endpoint_config;
	
	my @keys	= $cgi->param;
	foreach my $key (grep { /^(add|delete)_/ } sort @keys) {
		if ($key eq 'add_uri') {
			my $url		= $cgi->param($key);
			if ($url) {
				$self->_add_uri( $url );
			}
		} elsif ($key =~ /^delete_<(.*)>$/) {
			my $url	= $1;
			my $ctx	= RDF::Trine::Node::Resource->new( $url );
			$model->remove_statements( undef, undef, undef, $ctx );
		}
		
	}
	$self->redir( $cgi, 302, "Found", $self->admin_url );
}

sub _add_uri {
	my $self	= shift;
	my $url		= shift;
	my $ua		= $self->_agent;
	my $resp	= $ua->get($url);
	my $model	= $self->_model;
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
			$model->add_statement( $stmt, $basenode );
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
	
	my $model	= $self->_model;
	my $tt		= $self->_template;
	my $file	= 'admin_index.html';

	my @files;
	my $stream	= $model->get_contexts;
	while (my $c = $stream->next) {
		my $uri		= $c->as_string;
		my $count	= $model->count_statements( undef, undef, undef, $c );
		push( @files, {
			source			=> _html_escape($uri),
			count			=> $count,
			delete_field	=> $cgi->checkbox( -name => "delete_${uri}", -label => '', -checked => 0 ),
		} );
	}
	
	my $owner		= $self->owner_openid;
	my $auth_query	= $self->raw_auth_query();
	my $priv_preds	= join("\n", map { $_->uri_value } @{ $self->priv_preds });
	warn 'owner: ' . $owner;
	
	print $cgi->header( -type => 'text/html; charset=utf-8' );
	my $submit	= $self->admin_url;
	$tt->process( $file, {
		admin_submit_url	=> $submit,
		files				=> \@files,
		owner_openid		=> $owner,
		priv_preds			=> $priv_preds,
		auth_query			=> $auth_query,
	} );
}

sub save_query {
	my $self	= shift;
	my $cgi		= shift;
	my $sparql	= shift;
	my $query	= RDF::Query->new( $sparql );
	if ($query) {
		my $serial	= $query->as_sparql;
		my $dbh		= $self->dbh;
		
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
	} else {
		die RDF::Query->error;
	}
}

sub run_saved_query {
	my $self	= shift;
	my $cgi		= shift;
	my $name	= shift;

	my $dbh		= $self->dbh;
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
	# $self->save_query( $cgi, $sparql );
	
	my $model		= $self->_model;
	my $http_accept	= $ENV{HTTP_ACCEPT} || 'text/html';
	my @accept	= map { $_->[0] }
					sort { $b->[1] <=> $a->[1] }
						map { my ($t,$q) = split(/;q=/, $_); $q ||= 1; [ $t,$q ] }
							sort { index($b, 'html') }
								split(',', $http_accept);
	my %ok		= map { $_ => 1 } qw(text/plain text/xml application/rdf+xml application/sparql-results+json application/json text/html application/xhtml+xml application/sparql-results+xml);
	if (my $t = $cgi->param('mime-type')) {
		unshift( @accept, $t );
	}
	my @types	= (grep { exists($ok{ $_ }) } @accept);
	
	my $query	= RDF::Query->new( $sparql );
	unless ($query) {
		my $error	= RDF::Query->error;
		return $self->error( $cgi, 400, 'Bad Request', $error );
	}
	my $stream	= $query->execute( $model );
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
			if ($type =~ /html/) {
				print $cgi->header( -type => 'text/html; charset=utf-8' );
				my $total	= 0;
				my $rtype	= $stream->type;
				my $rstream	= ($rtype eq 'graph') ? $stream->unique() : $stream;
				$tt->process( $file, {
					result_type => $rtype,
					next_result => sub { my $r = $rstream->next_result; $total++ if ($r); return $r },
					columns		=> sub { $rstream->binding_names },
					values		=> sub {
									my $row 	= shift;
									my $col 	= shift;
									my $node	= $row->{ $col };
									my $str		= ($node) ? $node->as_string : '';
									return _html_escape( $str )
								},
					boolean		=> sub { $rstream->get_boolean },
					nodes		=> sub {
									my $s 		= shift;
									my @nodes	= map { $s->$_() } qw(subject predicate object);
									my @strs	= map { ($_) ? $_->as_string : '' } @nodes;
									return [ map { _html_escape( $_ ) } @strs ];
								},
					total		=> sub { $total },
					feed_url	=> $self->feed_url( $cgi ),
				} ) or warn $tt->error();
			} elsif ($type =~ /xml/) {
				print $cgi->header( -type => "$type; charset=utf-8" );
				print $stream->as_xml;
			} elsif ($type =~ /json/) {
				print $cgi->header( -type => "$type; charset=utf-8" );
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
				my $node	= $row->{ $k };
				my $value	= ($node) ? $node->as_string : '';
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

sub owner_openid {
	my $self	= shift;
	return $self->{config}{owner_openid};
}

sub auth_query {
	my $self	= shift;
	my $id		= shift || '[%USER_OPENID%]';
	my $query	= $self->raw_auth_query;
	$query		=~ s/\[%USER_OPENID%\]/<$id>/g;
	my $owner	= $self->owner_openid;
	$query		=~ s/\[%OWNER_OPENID%\]/<$owner>/g;
	return $query;
}

sub raw_auth_query {
	my $self	= shift;
	my $query	= $self->{config}{auth_query};
	return $query;
}

sub update_auth_query {
	my $self	= shift;
	my $query	= shift;
	my $dbh		= $self->dbh;
	if ($query ne $self->auth_query) {
		my $sth	= $dbh->prepare('UPDATE Endpoint SET auth_query = ? WHERE ID = 1');
		$sth->execute( $query );
	}
}

sub priv_preds {
	my $self	= shift;
	return $self->{config}{priv_preds} || [];
}

sub update_priv_preds {
	my $self	= shift;
	my $preds	= shift;
	my $dbh		= $self->dbh;
	
	my @new_preds	= sort grep { length($_) } split(/\s+/, $preds);
	my @old_preds	= map { $_->uri_value } @{ $self->priv_preds };
	if (join('<', @new_preds) ne join('<', @old_preds)) {
		my $add	= $dbh->prepare('INSERT INTO Endpoint_PrivatePredicates (endpoint, ID, URI) VALUES (1,?,?)');
		my $rm	= $dbh->prepare('DELETE FROM Endpoint_PrivatePredicates WHERE URI = ?');
		
		my %old_preds	= map { $_ => 1 } @old_preds;
		foreach my $new (@new_preds) {
			if ($old_preds{ $new }) {
				delete $old_preds{ $new };
			} else {
				my $node	= RDF::Trine::Node::Resource->new( $new );
				my $id		= RDF::Trine::Store::DBI->_mysql_node_hash( $node );
				$add->execute( $id, $new );
			}
		}
		foreach my $old (keys %old_preds) {
			$rm->execute( $old );
		}
	}
}

sub _load_endpoint_config {
	my $self	= shift;
	my $dbh		= $self->dbh;
	my ($owner, $auth)	= $dbh->selectrow_array( 'SELECT owner_openid, auth_query FROM Endpoint WHERE ID = 1' );
	$self->{config}{owner_openid}	= $owner;
	$self->{config}{auth_query}		= $auth;
	
	my $sth		= $dbh->prepare( 'SELECT URI FROM Endpoint_PrivatePredicates WHERE endpoint = 1' );
	$sth->execute();
	
	my @preds;
	while (my ($uri) = $sth->fetchrow) {
		push( @preds, RDF::Trine::Node::Resource->new( $uri ) );
	}
	$self->{config}{priv_preds}	= [ sort @preds ];
	return $owner;
}

sub set_owner_openid {
	my $self	= shift;
	my $id		= shift;
	my $dbh		= $self->dbh;
	my $sth		= $dbh->prepare( 'UPDATE Endpoint SET owner_openid = ? WHERE ID = 1' );
	$sth->execute( $id );
}

sub admin_url {
	my $self	= shift;
	return $self->{admin};
}

sub submit_url {
	my $self	= shift;
	return $self->{submit};
}

sub set_identity {
	my $self	= shift;
	my $id		= shift;
	$self->{_identity}	= $id;
}

sub get_identity {
	my $self	= shift;
	my $id	= $self->{_identity};
	return $id;
}

sub _template {
	my $self	= shift;
	return $self->{_tt};
}

sub _agent {
	my $self	= shift;
	return $self->{_ua};
}

sub _model {
	my $self	= shift;
	return $self->{_model};
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
	my $dbh		= $self->dbh;
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Queries (
            Name VARCHAR(8) UNIQUE NOT NULL,
            Query longtext NOT NULL
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Endpoint (
            ID bigint unsigned PRIMARY KEY AUTO_INCREMENT,
            owner_openid VARCHAR(256) NOT NULL,
            include_path VARCHAR(256) NOT NULL,
            auth_query VARCHAR(1024),
            priv_query VARCHAR(1024)
        );
END
	$dbh->do( <<"END" ) || do { $dbh->rollback; return undef };
        CREATE TABLE IF NOT EXISTS Endpoint_PrivatePredicates (
            endpoint bigint unsigned,
            ID bigint unsigned,
            URI text NOT NULL,
            PRIMARY KEY (endpoint, ID)
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

sub dbh {
	my $self	= shift;
	my $dbh		= $self->_model->_store->dbh;
	return $dbh;
}

1;

__END__
