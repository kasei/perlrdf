=head1 NAME

RDF::Trine::Store::Dydra - RDF Store proxy for a Dydra endpoint

=head1 VERSION

This document describes RDF::Trine::Store::Dydra version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Store::Dydra;

=head1 DESCRIPTION

RDF::Trine::Store::Dydra provides a RDF::Trine::Store API to interact with a
remote Dydra endpoint.

=cut

package RDF::Trine::Store::Dydra;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store::SPARQL);

use URI::Escape;
use Data::Dumper;
use List::Util qw(first);
use Scalar::Util qw(refaddr reftype blessed);
use HTTP::Request::Common ();
use JSON;

use RDF::Trine::Error qw(:try);

######################################################################

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "1.012";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $user, $repo, $token ) >>

Returns a new storage object that will act as a proxy for the Dydra endpoint
for the $repo repository of $user, using the given API $token.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<Dydra> for this backend.

The following key must also be used:

=over

=item C<user>

The Dydra username.

=item C<token>

The Dydra API token.

=item C<repo>

The Dydra repository name.

=back

=cut

sub new {
	my $class	= shift;
	my $user	= shift;
	my $repo	= shift;
	my $token	= shift;
	my $ua		= RDF::Trine->default_useragent->clone;
	my $accept	= join(',',
					"application/sparql-results+json",
					"application/rdf+xml;q=0.5",
					"application/x-turtle;q=0.7",
					"application/json;q=0.4",
					"text/turtle;q=0.7",
					"text/xml;q=0.1"
				);
	$ua->default_headers->push_header( 'Accept' => $accept );
	$ua->credentials("dydra.com:80", "Application", $token, "X");
	$ua->credentials("dydra.com", "Application", $token, "X");
	
	my $base	= "http://dydra.com:80";
	my $url		= "${base}/${user}/${repo}/sparql";
	my $self	= bless({
		ua		=> $ua,
		base	=> $base,
		url		=> $url,
		user	=> $user,
		repo	=> $repo,
		token	=> $token,
	}, $class);
	
	# check if this repo already exists, otherwise create it
	$self->_create_repo( $user, $repo );
	
	return $self;
}

=item C<< base >>

Returns the service base URI ("http://dydra.com:80" by default).

=cut

sub base {
	my $self	= shift;
	return $self->{base};
}

sub _create_repo {
	my $self	= shift;
	my $user	= shift;
	my $repo	= shift;
	my $ua		= $self->{ua};
	my $base	= $self->base;
	my $repourl	= "${base}/${user}/repositories";
	my $req		= HTTP::Request->new(GET => $repourl);
	$req->header(Accept => "application/json");
	$req->header(Host => "dydra.com");
	$req->authorization_basic($self->{token}) if (defined $self->{token});
	my $resp	= $ua->request( $req );
	if ($resp->is_success) {
		my $data	= from_json($resp->content);
		my %repos;
		foreach my $r (@$data) {
			$repos{ $r->{name} }	= $r;
		}
		unless ($repos{ $repo }) {
			my $req	= HTTP::Request::Common::POST( $repourl, [
				'repository[name]'	=> $repo,
			] );
			$req->authorization_basic($self->{token}) if (defined $self->{token});
			$req->header(Accept => "application/json");
			my $resp	= $ua->request( $req );
			if ($resp->is_success) {
				# OK
			} else {
				my $status	= $resp->status_line;
				warn Dumper($resp);
				throw RDF::Trine::Error::DatabaseError -text => "Error making remote REST call attempting to create repository '$repo' ($status)";
			}
		}
	} else {
		my $status	= $resp->status_line;
		warn Dumper($resp);
		throw RDF::Trine::Error::DatabaseError -text => "Error making remote REST call in new ($status)";
	}
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config );
}

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'Dydra';
	return $proto->SUPER::new_with_config( $config );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	return $class->new( @{ $config }{qw(user repo token)} );
}

sub _config_meta {
	return {
		required_keys	=> [qw(user repo token)],
		fields			=> {
			user	=> { description => 'Dydra username', type => 'string' },
			repo	=> { description => 'Dydra repository name', type => 'string' },
			token	=> { description => 'Dydra API token', type => 'string' },
		}
	}
}



=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to add_statement";
	}
	
	if ($st->isa('RDF::Trine::Statement::Quad') and blessed($context)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "add_statement cannot be called with both a quad and a context";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_add_statements', $st, $context]);
	} else {
		my $s		= RDF::Trine::Serializer::NTriples->new();
		my $ua		= $self->{ua};
		my $user	= $self->{user};
		my $repo	= $self->{repo};
		my $base	= $self->base;
		my $url		= "${base}/${user}/${repo}/statements";
		if ($st->isa('RDF::Trine::Statement::Quad') or $context) {
			my $g	= $context || $st->context;
			$url	.= '?context=' . uri_escape($g->uri_value);
		}
		my $req		= HTTP::Request->new(POST => $url);
		$req->authorization_basic($self->{token}) if (defined $self->{token});
		$req->content_type('text/plain');
		$req->content($s->statement_as_string($st));
		
		warn "add_statement request: " . Dumper($req);
		
		my $resp	= $ua->request( $req );
		if ($resp->is_success) {
			return;
		} else {
			my $status	= $resp->status_line;
			warn Dumper($resp);
			throw RDF::Trine::Error::DatabaseError -text => "Error making remote REST call in add_statement ($status)";
		}
	}
	return;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to remove_statement";
	}
	
	if ($st->isa('RDF::Trine::Statement::Quad') and blessed($context)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "remove_statement cannot be called with both a quad and a context";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statements', $st, $context]);
	} else {
		my $s		= RDF::Trine::Serializer::NTriples->new();
		my $ua		= $self->{ua};
		my $user	= $self->{user};
		my $repo	= $self->{repo};
		my $base	= $self->base;
		my $data	= $s->statement_as_string($st);
		if ($st->isa('RDF::Trine::Statement::Quad') or $context) {
			my $g	= $context || $st->context;
			my $uri	= $g->uri_value;
			$data	= "GRAPH <$uri> { $data }";
		}
		my $sparql	= "DELETE DATA { $data }";
		my $url		= "${base}/${user}/${repo}/sparql";
		my $req		= HTTP::Request::Common::POST( $url, [ query => $sparql ] );
		$req->authorization_basic($self->{token}) if (defined $self->{token});
		my $resp	= $ua->request( $req );
		warn 'remove_statement: ' . Dumper($req, $resp);
		
		if ($resp->is_success) {
			return;
		} else {
			my $status	= $resp->status_line;
			warn Dumper($resp);
			throw RDF::Trine::Error::DatabaseError -text => "Error making remote REST call in remove_statement ($status)" . Dumper($st);
		}
	}
	return;
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to remove_statements";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statement_patterns', $st, $context]);
	} else {
		warn "do DELETE for remove_statements";
		throw RDF::Trine::Error::UnimplementedError -text => "remove_statements not implemented for Dydra stores yet";
	}
	return;
}

=item C<< count_statements ( $subject, $predicate, $object, $context ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and context. Any of the arguments may be undef to match any
value.

=cut

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	my $self	= shift;
	my %features	= map { $_ => 1 } (
		'http://www.w3.org/ns/sparql-service-description#SPARQL10Query',
		'http://www.w3.org/ns/sparql-service-description#SPARQL11Query',
	);
	if (@_) {
		my $f	= shift;
		return $features{ $f };
	} else {
		return keys %features;
	}
}

=item C<< get_sparql ( $sparql ) >>

Returns an iterator object of all bindings matching the specified SPARQL query.

=cut

sub get_sparql {
	my $self	= shift;
	my $sparql	= shift;
	my $ua		= $self->{ua};
	
	my $urlchar	= ($self->{url} =~ /\?/ ? '&' : '?');
	my $url		= $self->{url} . $urlchar . 'query=' . uri_escape($sparql);
	my $response	= $ua->get( $url );
	if ($response->is_success) {
		my $content	= $response->content;
		my $iter	= RDF::Trine::Iterator->from_json( $content );
		return $iter;
	} else {
		my $status		= $response->status_line;
		my $endpoint	= $self->{url};
		warn Dumper($response);
		throw RDF::Trine::Error::DatabaseError -text => "Error making remote SPARQL call to endpoint $endpoint ($status)";
	}
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	my $ua		= $self->{ua};
	my $user	= $self->{user};
	my $repo	= $self->{repo};
	my $base	= $self->base;
	my $url		= "${base}/${user}/${repo}/size";
	my $req		= HTTP::Request->new(GET => $url);
	$req->authorization_basic($self->{token}) if (defined $self->{token});
	$req->header(Accept => 'text/plain');
	my $resp	= $ua->request( $req );
	if ($resp->is_success) {
		warn 'size(): ' . Dumper($req, $resp);
		return 0+$resp->content;
	} else {
		my $status	= $resp->status_line;
		warn 'size() failed: ' . Dumper($resp);
		throw RDF::Trine::Error::DatabaseError -text => "Error making remote REST call in size ($status)";
	}
}

sub _end_bulk_ops {
	my $self			= shift;
	if (scalar(@{ $self->{ ops } || []})) {
		my @ops	= splice(@{ $self->{ ops } });
		my @aggops	= $self->_group_bulk_ops( @ops );
		my @sparql;
		warn '_end_bulk_ops: ' . Dumper(\@aggops);
		throw RDF::Trine::Error::UnimplementedError -text => "bulk operations not implemented for Dydra stores yet";
	}
	$self->{BulkOps}	= 0;
}

=item C<< nuke >>

Permanently removes the store and its data.

=cut

sub nuke {
	my $self	= shift;
	my $ua		= $self->{ua};
	my $user	= $self->{user};
	my $repo	= $self->{repo};
	my $base	= $self->base;
	my $url		= "${base}/${user}/${repo}";
	my $req		= HTTP::Request->new(DELETE => $url);
	$req->authorization_basic($self->{token}) if (defined $self->{token});
	my $resp	= $ua->request( $req );
	if ($resp->is_success) {
		return;
	} else {
		my $status	= $resp->status_line;
		warn 'nuke failed: ' . Dumper($resp);
		throw RDF::Trine::Error::DatabaseError -text => "Error making remote REST call in remove_statement ($status)";
	}
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
