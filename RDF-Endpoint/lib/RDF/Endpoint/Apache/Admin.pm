package RDF::Endpoint::Apache::Admin;

use strict;
use warnings;
use base qw(RDF::Endpoint::Apache);

sub run {
	my $self	= shift;
	my $cgi		= shift;
	my $endpoint	= $self->{endpoint};
	binmode( \*STDOUT, ':utf8' );
	
	my $url		= $cgi->url( -absolute => 1 );
	my $prefix	= $self->prefix;
	my $path	= $url;
	$path		=~ s/$prefix//;
	
	
	no warnings 'uninitialized';
	my $host	= $cgi->server_name;
	my $port	= $cgi->server_port;
	if ($cgi->param('submit')) {
		$endpoint->handle_admin_post( $cgi, $host, $port, $prefix );
	} else {
		$endpoint->admin_index( $cgi, $prefix );
	}
}

1;

__END__
