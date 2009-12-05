=head1 NAME

RDF::LinkedData - mod_perl handler class for serving RDF as linked data

=cut

package RDF::LinkedData;

use strict;
use warnings;

use Data::Dumper;
use Apache2::Request;
use HTTP::Negotiate qw(choose);
use URI::Escape qw(uri_escape);
use Apache2::Const qw(OK HTTP_SEE_OTHER REDIRECT DECLINED SERVER_ERROR HTTP_NO_CONTENT HTTP_NOT_IMPLEMENTED NOT_FOUND);

use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Serializer::RDFXML;

use Error qw(:try);

=head1 METHODS

=over 4

=item C<< handler >> ( $apache_req )

Main mod_perl handler method.

=cut

sub handler : method {
	my $class 	= shift;
	my $r	  	= shift;
	
	my $status;
	
	my $handler	= $class->new( $r );
	if (!$handler) {
		warn "couldn't get a handler";
		return DECLINED;
	} else {
		return $handler->run();
	}
}

=item C<< new >> ( $apache_req )

Creates a new handler object, given an Apache Request object.

=cut

sub new {
	my $proto	= shift;
	my $class   = ref($proto) || $proto;
	my $r		= shift;
	throw Mentok::ArgumentError unless (ref $r);

	my $base		= $r->dir_config( 'LinkedData_Base' );
	my $dbmodel		= $r->dir_config( 'LinkedData_Model' );
	my $dbuser		= $r->dir_config( 'LinkedData_User' );
	my $dbpass		= $r->dir_config( 'LinkedData_Password' );
	my $dsn			= $r->dir_config( 'LinkedData_DSN' );
	my $store		= RDF::Trine::Store::DBI->new( $dbmodel, $dsn, $dbuser, $dbpass );
	my $model		= RDF::Trine::Model->new( $store );
	
	my $self = bless( {
		_r	=> $r,
		_model => $model,
		_base => $base,
	}, $class );

	return $self;
} # END sub new

sub request {
	my $self	= shift;
	return $self->{_r};
}

sub model {
	my $self	= shift;
	return $self->{_model};
}

sub base {
	my $self	= shift;
	return $self->{_base};
}

sub run {
	my $self	= shift;
	my $r		= $self->request;
	
	
	my $uri		= $r->uri;
	my $base	= $self->base;
	my $model	= $self->model;
	my $variants = [
		['html',	1.000, 'text/html', undef, undef, undef, 1],
		['html',	0.500, 'application/xhtml+xml', undef, undef, undef, 1],
		['rdf-nt',	0.900, 'text/plain', undef, undef, undef, 1],
		['rdf-nt',	0.900, 'text/rdf', undef, undef, undef, 1],
		['rdf-nt',  0.900, 'application/x-turtle', undef, undef, undef, 1],
		['rdf-nt',  0.900, 'application/turtle', undef, undef, undef, 1],
		['rdf-nt',  0.900, 'text/n3', undef, undef, undef, 1],
		['rdf-xml',	0.950, 'application/rdf+xml', undef, undef, undef, 1],
	];
	my $choice	= choose($variants) || 'html';
	
	if ($uri =~ m<^(.+)/(data|page)$>) {
		my $first	= $1;
		my $type	= $2;
		my $iri	= sprintf( '%s%s', $base, $first );
		
		# not happy with this, but it helps for clients that do content sniffing based on filename
		$iri	=~ s/.(nt|rdf|ttl)$//;
		
		my $node	= RDF::Trine::Node::Resource->new( $iri );
		my $count	= $model->count_statements( $node, undef, undef );
		
		$r->header_out('Vary', join ", ", qw(Accept));
		if ($count > 0) {
			if ($type eq 'data') {
				if ($choice =~ /nt/) {
					my $s		= RDF::Trine::Serializer::NTriples->new();
					my $string	= $s->_serialize_bounded_description( $model, $node );
					$r->content_type('text/plain');
					$r->print("# Data for <$iri>\n");
					$r->print($string);
					return OK;
				} else {
					my $s		= RDF::Trine::Serializer::RDFXML->new();
					my $string	= $s->_serialize_bounded_description( $model, $node );
					$r->content_type('application/rdf+xml');
					$r->print($string);
					return OK;
				}
			} else {
				$r->content_type('text/html');
				$r->print(<<"END");
Page for &lt;$iri&gt;<br/>
URI: &lt;$uri&gt;<br/>
END
				return OK;
			}
		} else {
			return NOT_FOUND;
		}
	} else {
		$r->err_header_out('Vary', join ", ", qw(Accept));
		if ($choice =~ /^rdf/) {
			$r->err_header_out(Location => "${base}${uri}/data");
		} else {
			$r->err_header_out(Location => "${base}${uri}/page");
		}
		return HTTP_SEE_OTHER;
	}
}


1;
