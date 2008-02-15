package RDF::Endpoint::Apache::Admin;

use strict;
use warnings;
no warnings 'redefine';
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
	
	my $r		= $self->{_r};
	my $id		= $endpoint->get_identity;
	my $owner	= $r->dir_config( 'EndpointOwnerIdentity' );
	
	if ($owner and ($owner eq $id)) {
		no warnings 'uninitialized';
		my $host	= $cgi->server_name;
		my $port	= $cgi->server_port;
		if ($cgi->param('submit')) {
			$endpoint->handle_admin_post( $cgi, $host, $port, $prefix );
		} else {
			$endpoint->admin_index( $cgi, $prefix );
		}
	} else {
		$self->error( $cgi, 401, 'Unauthorized', 'You need to be the owner of this endpoint and logged in with OpenID to access the admin page.' );
	}
}

1;

__END__
