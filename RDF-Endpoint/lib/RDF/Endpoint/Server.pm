package RDF::Endpoint::Server;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Endpoint::Error qw(:try);
use Scalar::Util qw(reftype);
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
						SubmitURL	=> "http://${hostname}/${prefix}sparql",
					);
	$self->{endpoint}	= $endpoint;
	$self->{prefix}		= $prefix || '';
	if (defined($args{ banner })) {
		$self->{banner}		= $args{ banner };
	}
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
						SubmitURL	=> "http://${hostname}/${prefix}sparql",
					);
	$self->{endpoint}	= $endpoint;
	$self->{prefix}		= $prefix || '';
	if (defined($args{ banner })) {
		$self->{banner}		= $args{ banner };
	}
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
	
	my $stdout	= select();
	my $content	= '';
	my $sparql	= $cgi->param('query');
	try {
		if ($sparql) {
			open( my $fh, '>', \$content );
			my $out	= select( $fh );
			$endpoint->run_query( $cgi, $sparql );
			select($out);
			close($fh);
		} elsif ($path =~ m#^/(sparql)?$#) {
			open( my $fh, '>', \$content );
			my $out	= select( $fh );
			$endpoint->query_page( $cgi, $prefix );
			select($out);
			close($fh);
		} else {
			my $url	= "${domain}/";
			$self->redir( 303, 'See Other', $url );
		}
		
		print "HTTP/1.1 200 OK\n";
		print $content;
	} catch RDF::Endpoint::Error::MalformedQuery with {
		my $e		= shift;
		select($stdout);
		$self->error( 400, 'Bad Request', $e->text );
	} catch RDF::Endpoint::Error::EncodingError with {
		my $e		= shift;
		select($stdout);
		$self->error( 406, 'Not Acceptable', $e->text );
	} except {	# this will catch RDF::Endpoint::Error::InternalError and any unknown exceptions
		my $e		= shift;
		select($stdout);
		$self->error( 500, 'Internal Server Error', $e->text );
	};
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
	my $self	= shift;
	if (defined(my $b = $self->{banner})) {
		if (reftype($b) eq 'CODE') {
			$b->( $self );
		} else {
			print $b;
		}
	}
	return;
}

1;

__END__
