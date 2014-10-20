package Plack::App::RDF::Endpoint;

use strict;
use warnings;

use parent qw( Plack::Component );
use RDF::Endpoint;
use Plack::Request;

our $VERSION	= '0.07';

=head1 NAME

Plack::App::RDF::Endpoint - A Plack application for running RDF::Endpoint

=head1 VERSION

This document describes Plack::App::RDF::Endpoint version 0.07.

=head1 SYNOPSIS

  my $config  = {
    store => 'Memory',
    endpoint  => { endpoint_path   => '/' },
  };

  my $ep = Plack::App::RDF::Endpoint->new();
  $ep->configure($config);
  my $app = $ep->to_app;

  builder {
    enable "Head";
    enable "ContentLength";
    $app;
  };

=head1 METHODS

=over

=item C<< configure >>

This is the only method you would call manually, as it can be used to
pass a hashref with configuration to the application.

=cut

sub configure {
	my $self = shift;
	$self->{config} = shift;
	return $self;
}


=item C<< prepare_app >>

Will be called by Plack to set the application up.

=item C<< call >>

Will be called by Plack to process the request.

=back

=cut


sub prepare_app {
	my $self = shift;
	my $config = $self->{config};
	$self->{endpoint} = eval { RDF::Endpoint->new( $config ) };
	if ($@) {
		warn $@;
	}
}

sub call {
	my($self, $env) = @_;
	my $req	= Plack::Request->new($env);
	unless ($req->method =~ /^(GET|HEAD|POST)$/) {
		return [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ];
	}

	my $ep	= $self->{endpoint};
	my $resp	= $ep->run( $req );
	return $resp->finalize;
}

1;



=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>
 
based on Plack::App::RDF::LinkedData by

 Kjetil Kjernsmo, C<< <kjetilk@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Gregory Todd Williams.

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any
damages arising from the use of this software.

Permission is granted to anyone to use this software for any
purpose, including commercial applications, and to alter it and
redistribute it freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must
   not claim that you wrote the original software. If you use this
   software in a product, an acknowledgment in the product
   documentation would be appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must
   not be misrepresented as being the original software.

3. This notice may not be removed or altered from any source
   distribution.

With the exception of the CodeMirror files, the files in this package may also
be redistributed and/or modified under the same terms as Perl itself.

The CodeMirror (Javascript and CSS) files contained in this package are
copyright (c) 2007-2010 Marijn Haverbeke, and licensed under the terms of the
same zlib license as this code.

=cut
