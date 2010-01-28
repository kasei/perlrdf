=head1 NAME

RDF::LinkedData::Apache - mod_perl2 handler class for serving RDF as linked data

=head1 VERSION

This document describes RDF::LinkedData::Apache version 0.001

=head1 SYNOPSIS

  <Location /rdf>
    SetHandler perl-script
    PerlResponseHandler RDF::LinkedData
    PerlSetVar LinkedData_Base http://host.name
    PerlSetVar LinkedData_Store SPARQL;http://localhost/sparql
  </Location>

=head1 DESCRIPTION

The RDF::LinkedData::Apache module is a mod_perl2 handler for serving RDF
content as linked data. To use this module, it should be set as a
PerlResponseHandler and PerlSetVar should be used to set the LinkedData_Base
and LinkedData_Store variables. The base variable represents the host name
RDF data will be served from (including the 'http://' prefix) while the store
variable must be a valid RDF::Trine::Store configuration string.

Using the configuration shown in the L</SYNOPSIS> section above, the server will
serve requests for resources with the prefix L<http://host.name/rdf> based on
sub-requests to the locally-accessible SPARQL endpoint available at
L<http://localhost/sparql>. The server will respond to the following types of
queries:

=over 4

* L<http://host.name/rdf/example>

Will return an HTTP 303 redirect based on the value of the request's Accept
header. If the Accept header contains a recognized RDF media type, the redirect
will be to L<http://host.name/rdf/example/data>, otherwise to
L<http://host.name/rdf/example/page>

* L<http://host.name/rdf/example/data>

Will return a bounded description of the L<http://host.name/rdf/example>
resource in an RDF serialization based on the Accept header. If the Accept
header does not contain a recognized media type, RDF/XML will be returned.

* L<http://host.name/rdf/example/page>

Will return an HTML description of the L<http://host.name/rdf/example> resource
including RDFa markup.

=back

If the RDF resource for which data is requested is not the subject of any RDF
triples in the underlying triplestore, the /page and /data redirects will take
place, but the subsequent request will return HTTP 404 (Not Found).

The HTML description of resources will be enhanced by having metadata about the
predicate of RDF triples loaded into the same triplestore. Currently, the
relevant metadata includes rdfs:label and dc:description statements about
predicates. For example, if the triplestore contains the statement

 <http://host.name/rdf/example> <http://example/date> "2010" .

then also including the triple

 <http://example/date> <http://www.w3.org/2000/01/rdf-schema#label> "Creation Date" .

Would allow the HTML description of L<http://host.name/rdf/example> to include
a description including:

 Creation Date: 2010

instead of the less specific:

 date: 2010

which is simply based on attempting to extract a useful suffix from the
predicate URI.

=head1 METHODS

=over 4

=cut

package RDF::LinkedData::Apache;

use strict;
use warnings;

use Data::Dumper;
use Apache2::Request;
use Scalar::Util qw(blessed);
use HTTP::Negotiate qw(choose);
use URI::Escape qw(uri_escape);
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::Const qw(OK HTTP_SEE_OTHER REDIRECT DECLINED SERVER_ERROR HTTP_NO_CONTENT HTTP_NOT_IMPLEMENTED NOT_FOUND);

use RDF::Trine 0.114;
use RDF::Trine qw(iri);
use RDF::Trine::Serializer::NTriples;
use RDF::Trine::Serializer::RDFXML;
use RDF::Query;

use Error qw(:try);

=item C<< handler ( $apache_req ) >>

Main mod_perl handler method.

=cut

sub handler : method {
	my $class 	= shift;
	my $r	  	= shift;
	
	my $filename	= $r->filename;
	if (-r $filename and -f _) {
		return Apache2::Const::DECLINED;
	}
	
	my $status;
	my $handler	= $class->new( $r );
	if (!$handler) {
		warn "couldn't get a handler";
		return Apache2::Const::DECLINED;
	} else {
		return $handler->run();
	}
}

=item C<< new ( $apache_req ) >>

Creates a new handler object, given an Apache Request object.

=cut

sub new {
	my $class	= shift;
	my $r		= shift;
	throw Error -text => "Missing request object in RDF::LinkedData::Apache constructor" unless (blessed($r));
	
	my $base	= $r->dir_config( 'LinkedData_Base' );
	my $config	= $r->dir_config( 'LinkedData_Store' );
	my $store	= RDF::Trine::Store->new_with_string( $config );
	my $model	= RDF::Trine::Model->new( $store );
	
	my $self = bless( {
		_r		=> $r,
		_model	=> $model,
		_base	=> $base,
		_cache	=> {},
	}, $class );

	return $self;
} # END sub new

=item C<< request >>

Returns the Apache request object.

=cut

sub request {
	my $self	= shift;
	return $self->{_r};
}

=item C<< model >>

Returns the RDF::Trine::Model object.

=cut

sub model {
	my $self	= shift;
	return $self->{_model};
}

=item C<< base >>

Returns the base URI for this handler.

=cut

sub base {
	my $self	= shift;
	return $self->{_base};
}

=item C<< run >>

Runs the handler.

=cut

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
					return Apache2::Const::OK;
				} else {
					my $s		= RDF::Trine::Serializer::RDFXML->new();
					my $string	= $s->_serialize_bounded_description( $model, $node );
					$r->content_type('application/rdf+xml');
					$r->print($string);
					return Apache2::Const::OK;
				}
			} else {
				my $title		= $self->_title( $node );
				my $desc		= $self->_description( $node );
				my $description	= sprintf( "<table>%s</table>\n", join("\n\t\t", map { sprintf( '<tr><td>%s</td><td>%s</td></tr>', @$_ ) } @$desc) );
				$r->content_type('text/html');
				$r->print(<<"END");
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN"
	 "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>${title}</title>
</head>
<body xmlns:foaf="http://xmlns.com/foaf/0.1/">

<h1>${title}</h1>
<hr/>

<div>
	${description}
</div>

</body></html>
END
				return Apache2::Const::OK;
			}
		} else {
			return Apache2::Const::NOT_FOUND;
		}
	} else {
		$r->err_headers_out->add('Vary', join ", ", qw(Accept));
		if ($choice =~ /^rdf/) {
			$r->err_headers_out->add(Location => "${base}${uri}/data");
		} else {
			$r->err_headers_out->add(Location => "${base}${uri}/page");
		}
		return Apache2::Const::HTTP_SEE_OTHER;
	}
}

sub _title {
	my $self	= shift;
	my $node	= shift;
	my $nodestr	= $node->as_string;
	if (my $title = $self->{_cache}{title}{$nodestr}) {
		return $title;
	} else {
		my $model	= $self->model;
		my $name	= RDF::Trine::Node::Resource->new( 'http://xmlns.com/foaf/0.1/name' );
		my $title	= RDF::Trine::Node::Resource->new( 'http://purl.org/dc/elements/1.1/title' );
		my $label	= RDF::Trine::Node::Resource->new( 'http://www.w3.org/2000/01/rdf-schema#label' );
		
		{
			# optimistically assume that we'll get back a valid name on the first try
			my $name	= $model->objects_for_predicate_list( $node, $name, $title, $label );
			if (blessed($name) and $name->is_literal) {
				my $str	= $name->literal_value;
				$self->{_cache}{title}{$nodestr}	= $str;
				return $str;
			}
		}
		
		# if that didn't work, continue to try to find a valid literal title node
		my @names	= $model->objects_for_predicate_list( $node, $name, $title, $label );
		foreach my $name (@names) {
			if ($name->is_literal) {
				my $str	= $name->literal_value;
				$self->{_cache}{title}{$nodestr}	= $str;
				return $str;
			}
		}
		
		# and finally fall back on just returning a string version of the node
		if ($node->is_resource) {
			my $uri	= $node->uri_value;
			$self->{_cache}{title}{$nodestr}	= $uri;
			return $uri;
		} else {
			my $str	= $node->as_string;
			$self->{_cache}{title}{$nodestr}	= $str;
			return $str;
		}
	}
}

sub _description {
	my $self	= shift;
	my $node	= shift;
	my $model	= $self->model;
	
	my $iter	= $model->get_statements( $node );
	my @label	= (
					iri( 'http://www.w3.org/2000/01/rdf-schema#label' ),
					iri( 'http://purl.org/dc/elements/1.1/description' ),
				);
	my @desc;
	while (my $st = $iter->next) {
		my $p	= $st->predicate;
		
		my $ps;
		if (my $pname = $self->{_cache}{pred}{$p->as_string}) {
			$ps	= $pname;
		} elsif (my $pn = $model->objects_for_predicate_list( $p, @label )) {
			$ps	= $self->_html_node_value( $pn );
		} elsif ($p->is_resource and $p->uri_value =~ m<^http://www.w3.org/1999/02/22-rdf-syntax-ns#_(\d+)$>) {
			$ps	= '#' . $1;
		} else {
			# try to turn the predicate into a qname and use the local part as the printable name
			my $name;
			try {
				(my $ns, $name)	= $p->qname;
			} catch RDF::Trine::Error with {};
			if ($name) {
				my $title	= _escape( $name );
				$ps	= $title;
			} else {
				$ps	= _escape( $p->uri_value );
			}
		}
		
		$self->{_cache}{pred}{$p->as_string}	= $ps;
		my $obj	= $st->object;
		my $os	= $self->_html_node_value( $obj, $p );
		
		push(@desc, [$ps, $os]);
	}
	return \@desc;
}

sub _html_node_value {
	my $self		= shift;
	my $n			= shift;
	my $rdfapred	= shift;
	my $qname		= '';
	my $xmlns		= '';
	if ($rdfapred) {
		try {
			my ($ns, $ln)	= $rdfapred->qname;
			$xmlns	= qq[xmlns:ns="${ns}"];
			$qname	= qq[ns:$ln];
		} catch RDF::Trine::Error with {};
	}
	return '' unless (blessed($n));
	if ($n->is_literal) {
		my $l	= _escape( $n->literal_value );
		if ($qname) {
			return qq[<span $xmlns property="${qname}">$l</span>];
		} else {
			return $l;
		}
	} elsif ($n->is_resource) {
		my $uri		= _escape( $n->uri_value );
		my $title	= _escape( $self->_title( $n ) );
		
		if ($qname) {
			return qq[<a $xmlns rel="${qname}" href="${uri}">$title</a>];
		} else {
			return qq[<a href="${uri}">$title</a>];
		}
	} else {
		return $n->as_string;
	}
}

sub _escape {
	my $l	= shift;
	for ($l) {
		s/&/&amp;/g;
		s/</&lt;/g;
		s/"/&quot;/g;
	}
	return $l;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
