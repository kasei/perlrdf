package RDF::Endpoint::Server;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Endpoint;
use base qw(HTTP::Server::Simple::CGI);

sub new_with_model {
	my $class		= shift;
	my $model		= shift;
	my %args		= @_;
	my $port		= $args{ Port };
	my $prefix		= $args{ Prefix };
	my $incpath		= $args{ IncludePath };
	my $cgi			= $args{ CGI } || do { require CGI; CGI->new() };

	my $host		= $cgi->server_name;
	my $hostname	= ($port == 80) ? $host : join(':', $host, $port);
	my $self		= $class->SUPER::new( $port );
	my $endpoint	= RDF::Endpoint->new_with_model(
						$model,
						IncludePath => $incpath,
						AdminURL	=> "http://${hostname}/${prefix}admin/",
						SubmitURL	=> "http://${hostname}/${prefix}sparql",
					);
	$self->{endpoint}	= $endpoint;
	$self->{prefix}		= $prefix || '';
	return $self;
}

sub new {
	my $class		= shift;
	my %args		= @_;
	
	my $port		= $args{ Port };
	my $dsn			= $args{ DBServer };
	my $user		= $args{ DBUser };
	my $pass		= $args{ DBPass };
	my $model		= $args{ Model };
	my $prefix		= $args{ Prefix };
	my $incpath		= $args{ IncludePath };
	my $cgi			= $args{ CGI } || do { require CGI; CGI->new() };
	
	my $host	= $cgi->server_name;
	my $hostname	= ($port == 80) ? $host : join(':', $host, $port);
	my $self		= $class->SUPER::new( $port );
	my $endpoint	= RDF::Endpoint->new(
						$dsn,
						$user,
						$pass,
						$model,
						IncludePath => $incpath,
						AdminURL	=> "http://${hostname}/${prefix}admin/",
						SubmitURL	=> "http://${hostname}/${prefix}sparql",
					);
	$endpoint->init();
	$self->{endpoint}	= $endpoint;
	$self->{prefix}		= $prefix || '';
	return $self;
}

sub handle_request {
	my $self	= shift;
	my $cgi		= shift;
	my $endpoint	= $self->{endpoint};
	binmode( \*STDOUT, ':utf8' );
	
	my $port	= $self->port;
	my $host	= $self->host;
	my $path	= $ENV{REQUEST_URI};
	my $prefix	= $self->prefix;
	my $domain	= "http://${host}:${port}" . $prefix;
	my $url		= $domain . $path;
	
	if ($path =~ qr'^/sparql') {
		my $sparql	= $cgi->param('query');
		if ($sparql) {
			print "HTTP/1.1 200 OK\n";
			my $content	= '';
			open( my $fh, '>', \$content );
			my $out	= select( $fh );
			$endpoint->run_query( $cgi, $sparql );
			select($out);
			close($fh);
			use bytes;
			
			print "Content-Length: " . length($content) . "\n";
			print $content;
		} else {
			$self->error( 400, 'Bad Request', 'No query.' );
		}
	} elsif ($path =~ qr'^${prefix}/query/(\w+)') {
		my $query	= $endpoint->run_saved_query( $cgi, $1 );
	} else {
		if ($path =~ qr</$>) {
			my $url	= "${domain}${path}index.html";
			$self->redir( 303, 'See Other', $url );
		} elsif ($path =~ qr[^${prefix}/admin$]) {
			# POSTing data for the admin page
			$endpoint->handle_admin_post( $cgi, $host, $port, $prefix );
		} elsif ($path =~ qr[^${prefix}/admin/]) {
			if ($path =~ qr[^${prefix}/admin/index.html$]) {
				$endpoint->admin_index( $cgi, $prefix );
			} else {
				$self->error( 403, 'Forbidden', 'You do not have permission to access this resource' );
			}
		} elsif ($path =~ qr[^${prefix}/index.html$]) {
			my $content	= '';
			open( my $fh, '>', \$content );
			my $out	= select( $fh );
			$endpoint->query_page( $cgi, $prefix );
			select($out);
			close($fh);
			use bytes;
			
			print "HTTP/1.1 200 OK\n";
			print "Content-Length: " . length($content) . "\n";
			print $content;
		} else {
			$self->error( 403, 'Forbidden', 'You do not have permission to access this resource' );
		}
	}
}

sub prefix {
	my $self	= shift;
	return $self->{prefix};
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
	return;
}

sub print_banner {
	return;
}

1;

__END__
