package RDF::Endpoint::Apache;

use strict;
use warnings;
no warnings 'redefine';

use CGI;
use Log::Log4perl;
use Apache::DBI;
use RDF::Endpoint;
use Data::Dumper;
use LWPx::ParanoidAgent;
use Digest::SHA1 qw(sha1_hex);

my $secret			= q<G"dEMXI9N,:d'J;A>;
my $salt			= q<$*C@>;

sub handler ($$) {
	my $class	= shift;
	my $r		= shift;
	my $dsn		= $r->dir_config( 'EndpointDBServer' );
	my $user	= $r->dir_config( 'EndpointDBUser' );
	my $pass	= $r->dir_config( 'EndpointDBPass' );
	my $model	= $r->dir_config( 'EndpointModel' );
	my $inc		= $r->dir_config( 'EndpointIncludePath' );
	my $wl		= $r->dir_config( 'EndpointWhiteListModel' );
	$secret		= $r->dir_config( 'EndpointSecret' ) || $secret;
	$salt		= $r->dir_config( 'EndpointSalt' ) || $salt;
	
	if (my $xmpp_conf = $r->dir_config( 'EndpointXMPPConf' )) {
		require Log::Dispatch::Jabber;
		Log::Log4perl->init_and_watch( $xmpp_conf, 10 );
	}
	
	my $cgi		= CGI->new;
	
	my $endpoint		= $class->new(
		DBServer		=> $dsn,
		DBUser			=> $user,
		DBPass			=> $pass,
		Model			=> $model,
		IncludePath		=> $inc,
		CGI				=> $cgi,
		WhiteListModel	=> $wl,
	);
	
	$endpoint->{_r}	= $r;
	$endpoint->run( $cgi );
}

sub new {
	my $class		= shift;
	my %args		= @_;
	
	my $dsn			= $args{ DBServer };
	my $user		= $args{ DBUser };
	my $pass		= $args{ DBPass };
	my $model		= $args{ Model };
	my $prefix		= $args{ Prefix };
	my $incpath		= $args{ IncludePath };
	my $cgi			= $args{ CGI };
	my $wl			= $args{ WhiteListModel };
	
	my $host		= $cgi->server_name;
	my $port		= $cgi->server_port;
	my $hostname	= ($port == 80) ? $host : join(':', $host, $port);

	my $dbh			= DBI->connect( $dsn, $user, $pass );
	my $self		= bless({ dbh => $dbh }, $class);
	
	my %endargs;
	
	if ($wl) {
		$endargs{ WhiteListModel }	= $wl;
	}
	
	if (my $data = $cgi->cookie( -name => 'identity' )) {
		my ($id, $hash)	= split('>', $data, 2);
		if ($hash eq $self->_id_hash( $id )) {
			$endargs{ Identity }	= $id;
		}
	}
	
	my $endpoint	= RDF::Endpoint->new(
						$dsn,
						$user,
						$pass,
						$model,
						IncludePath => $incpath,
						SubmitURL	=> "http://${hostname}" . $cgi->url( -absolute => 1 ),
						AdminURL	=> "http://${hostname}" . join('?', $cgi->url( -absolute => 1 ), 'admin=1'),
						%endargs,
					);
	$endpoint->init();
	$self->{endpoint}	= $endpoint;
	$self->{prefix}		= $prefix || '';
	return $self;
}

sub run {
	my $self	= shift;
	my $cgi		= shift;
	my $endpoint	= $self->{endpoint};
	binmode( \*STDOUT, ':utf8' );
	
	my $url		= $cgi->url();
	my $absurl	= $cgi->url( -absolute => 1 );
	my $prefix	= $self->prefix;
	my $path	= $absurl;
	$path		=~ s/$prefix//;
	
	my $csr = Net::OpenID::Consumer->new(
		ua		=> LWPx::ParanoidAgent->new,
#		cache	=> Some::Cache->new,
		args	=> $cgi,
		consumer_secret => $secret,
	);
	
	no warnings 'uninitialized';
	my $host	= $cgi->server_name;
	my $port	= $cgi->server_port;
	
	if ($cgi->param('about')) {
		$endpoint->about( $cgi );
	} elsif ($cgi->param('openid.check')) {
		if (my $setup_url = $csr->user_setup_url) {
			# redirect/link/popup user to $setup_url
			warn "setup_url: $setup_url";
			$self->redir( $cgi, 303, 'See Other', $setup_url );
		} elsif ($csr->user_cancel) {
			# restore web app state to prior to check_url
			warn "restoring on cancel: $url";
			$self->redir( $cgi, 303, 'See Other', $url );
		} elsif (my $vident = $csr->verified_identity) {
			my $verified_url = $vident->url;
			warn "You are $verified_url !";
			$endpoint->set_identity( $verified_url );
			$self->redir( $cgi, 303, 'See Other', $url, $verified_url );
		} else {
			die "Error validating identity: " . $csr->err;
		}
	} elsif (my $id = $cgi->param('identity')) {
		my $claimed_identity = $csr->claimed_identity($id);
		if ($claimed_identity) {
			my $check_url = $claimed_identity->check_url(
				return_to  => "${url}?openid.check=1",
#				trust_root => "http://example.com/",
			);
			$self->redir( $cgi, 303, 'See Other', $check_url );
		} else {
			$endpoint->login_page( $cgi );
		}
	} elsif ($cgi->param('login')) {
		$endpoint->login_page( $cgi );
	} elsif ($cgi->param('logout')) {
		$self->redir( $cgi, 303, 'See Other', $url, '' );
	} elsif (my $sparql = $cgi->param('query')) {
		$endpoint->run_query( $cgi, $sparql );
	} elsif (my $q = $cgi->param('queryname')) {
		my $query	= $endpoint->run_saved_query( $cgi, $q );
	} else {
		$endpoint->query_page( $cgi, $prefix );
	}
}

sub prefix {
	my $self	= shift;
	return $self->{prefix};
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
	my $id		= shift;
	my %args;
	if (defined($id)) {
		my $hash			= $id . '>' . $self->_id_hash( $id );
		my $cookie			= $cgi->cookie(
								-name		=> 'identity',
								-value		=> $hash,
								-path		=> '/',
								-expires	=> '+1h',
							);
		$args{ -cookie }	= $cookie;
	}
	print $cgi->header( -status => "${code} ${message}", -Location => $url, %args );
	return;
}

sub dbh {
	my $self	= shift;
	return $self->{dbh};
}

sub _id_hash {
	my $self	= shift;
	my $id		= shift;
	$id			=~ tr/A-Za-z/N-ZA-Mn-za-m/;
	my $hash	= sha1_hex( $salt . $id );
	return $hash;
}

1;

__END__
