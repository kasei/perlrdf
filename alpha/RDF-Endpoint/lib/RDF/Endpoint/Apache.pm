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
use Apache2::Const qw(OK);

my $secret			= q<G"dEMXI9N,:d'J;A>;
my $salt			= q<$*C@>;

sub handler : method {
	my $class	= shift;
	my $r		= shift;
	my $dsn		= $r->dir_config( 'EndpointDBServer' );
	my $user	= $r->dir_config( 'EndpointDBUser' );
	my $pass	= $r->dir_config( 'EndpointDBPass' );
	my $model	= $r->dir_config( 'EndpointModel' );
	my $inc		= $r->dir_config( 'EndpointIncludePath' );
	$secret		= $r->dir_config( 'EndpointSecret' ) || $secret;
	$salt		= $r->dir_config( 'EndpointSalt' ) || $salt;
	
	my $cgi		= CGI->new;
	
	my $endpoint		= $class->new(
		DBServer		=> $dsn,
		DBUser			=> $user,
		DBPass			=> $pass,
		Model			=> $model,
		IncludePath		=> $inc,
		CGI				=> $cgi,
	);
	
	$endpoint->{_r}	= $r;
	$endpoint->run( $cgi );
	return OK;
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
	
	my $host		= $cgi->server_name;
	my $port		= $cgi->server_port;
	my $hostname	= ($port == 80) ? $host : join(':', $host, $port);

	my $dbh			= DBI->connect( $dsn, $user, $pass );
	my $self		= bless({ dbh => $dbh }, $class);
	
	my %endargs;
	
	my $endpoint	= RDF::Endpoint->new(
						$dsn,
						$user,
						$pass,
						$model,
						IncludePath => $incpath,
						SubmitURL	=> "http://${hostname}" . $cgi->url( -absolute => 1 ),
						%endargs,
					);
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
	
	no warnings 'uninitialized';
	my $host	= $cgi->server_name;
	my $port	= $cgi->server_port;
	
	if (my $sparql = $cgi->param('query')) {
		$endpoint->run_query( $cgi, $sparql );
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
	print $cgi->header( -status => "${code} ${message}", -Location => $url );
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
