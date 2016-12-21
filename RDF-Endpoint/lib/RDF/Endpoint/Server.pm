package RDF::Endpoint::Server;

use strict;
use warnings;
no warnings 'redefine';

use Carp qw(confess croak);
use Config::JFDI;
use Data::Dumper;
use LWP::MediaTypes qw(add_type);
use Plack::Builder;
use Plack::Request;
use Plack::Runner;
use RDF::Endpoint;
use Scalar::Util qw(reftype);

add_type( 'application/rdf+xml' => qw(rdf xrdf rdfx) );
add_type( 'text/turtle' => qw(ttl) );
add_type( 'text/plain' => qw(nt) );
add_type( 'text/x-nquads' => qw(nq) );
add_type( 'text/json' => qw(json) );
add_type( 'text/html' => qw(html xhtml htm) );

sub new {
	my $class		= shift;
	my $model		= shift;
	my %args		= @_;
	my $port		= $args{ Port };
	my $prefix		= $args{ Prefix };
	my $incpath		= $args{ IncludePath };

	my $config	= {
		endpoint	=> {
			service_description => {
				named_graphs	=> 1,
				default			=> 1,
			},
			html				=> {
				embed_images	=> 1,
				image_width		=> 200,
				resource_links	=> 1,
			},
			load_data	=> 0,
			update		=> 1,
        }
    };

	my @plackargs;
	if (defined($port)) {
		push(@plackargs, '--port', $port);
	}
	
	my $end		= RDF::Endpoint->new( $model, $config );
	return bless({ endpoint => $end, plackargs => \@plackargs }, $class);
}

sub run {
	my $self	= shift;
	my $end		= $self->{endpoint};
	my $runner	= Plack::Runner->new;
	my $app	= sub {
		my $env 	= shift;
		my $req 	= Plack::Request->new($env);
		my $resp	= $end->run( $req );
		return $resp->finalize;
	};
	$runner->parse_options(@{ $self->{ plackargs } });
	$runner->run($app);
}

sub background {
	# This code is taken from HTTP::Server::Simple
	my $self  = shift;
	my $child = fork;
	croak "Can't fork: $!" unless defined($child);
	return $child if $child;

	srand(); # after a fork, we need to reset the random seed
	# or we'll get the same numbers in both branches
	if ( $^O !~ /MSWin32/ ) {
		require POSIX;
		POSIX::setsid()
		or croak "Can't start a new session: $!";
	}
	$self->run(@_); # should never return
	exit;
}

1;

__END__
