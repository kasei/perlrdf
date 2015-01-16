# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class

=head1 VERSION

This document describes RDF::Trine::Parser version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 
 RDF::Trine::Parser->parse_url_into_model( $url, $model );
 
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 $parser->parse_into_model( $base_uri, $rdf, $model );
 
 $parser->parse_file_into_model( $base_uri, 'data.ttl', $model );

=head1 DESCRIPTION

RDF::Trine::Parser is a base class for RDF parsers. It may be used as a factory
class for constructing parser objects by name or media type with the C<< new >>
method, or used to abstract away the logic of choosing a parser based on the
media type of RDF content retrieved over the network with the
C<< parse_url_into_model >> method.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser;

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Encode qw(decode);
use LWP::MediaTypes;
use Module::Load::Conditional qw[can_load];

our ($VERSION);
our %file_extensions;
our %parser_names;
our %canonical_media_types;
our %media_types;
our %format_uris;
our %encodings;

BEGIN {
	$VERSION	= '1.012';
	can_load( modules => {
		'Data::UUID'	=> undef,
		'UUID::Tiny'	=> undef,
	} );
}

use Scalar::Util qw(blessed);

use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser::NTriples;
use RDF::Trine::Parser::NQuads;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Parser::RDFJSON;
use RDF::Trine::Parser::RDFa;

=item C<< media_type >>

Returns the canonical media type associated with this parser.

=cut

sub media_type {
	my $self	= shift;
	my $class	= ref($self) || $self;
	return $canonical_media_types{ $class };
}

=item C<< media_types >>

Returns the media types associated with this parser.

=cut

sub media_types {
	my $self	= shift;
	my @types;
	foreach my $type (keys %media_types) {
		my $class	= $media_types{ $type };
		push(@types, $type) if ($self->isa($class));
	}
	return @types;
}

=item C<< parser_by_media_type ( $media_type ) >>

Returns the parser class appropriate for parsing content of the specified media type.
Returns undef if not appropriate parser is found.

=cut

sub parser_by_media_type {
	my $proto	= shift;
	my $type	= shift;
	my $class	= $media_types{ $type };
	return $class;
}

=item C<< guess_parser_by_filename ( $filename ) >>

Returns the best-guess parser class to parse a file with the given filename.
Defaults to L<RDF::Trine::Parser::RDFXML> if not appropriate parser is found.

=cut

sub guess_parser_by_filename {
	my $class	= shift;
	my $file	= shift;
	if ($file =~ m/[.](\w+)$/) {
		my $ext	= $1;
		return $file_extensions{ $ext } if exists $file_extensions{ $ext };
	}
	return $class->parser_by_media_type( 'application/rdf+xml' ) || 'RDF::Trine::Parser::RDFXML';
}

=item C<< new ( $parser_name, @args ) >>

Returns a new RDF::Trine::Parser object for the parser with the specified name
(e.g. "rdfxml" or "turtle"). If no parser with the specified name is found,
throws a RDF::Trine::Error::ParserError exception.

Any C<< @args >> will be passed through to the format-specific parser
constructor.

If C<< @args >> contains the key-value pair C<< (canonicalize => 1) >>, literal
value canonicalization will be attempted during parsing with warnings being
emitted for invalid lexical forms for recognized datatypes.

=cut

sub new {
	my $class	= shift;
	my $name	= shift;
	my $key		= lc($name);
	$key		=~ s/[^a-z]//g;

	if ($name eq 'guess') {
		throw RDF::Trine::Error::UnimplementedError -text => "guess parser heuristics are not implemented yet";
	} elsif (my $class = $parser_names{ $key }) {
		# re-add name for multiformat (e.g. Redland) parsers
		return $class->new( name => $key, @_ );
	} else {
		throw RDF::Trine::Error::ParserError -text => "No parser known named $name";
	}
}

=item C<< parse_url_into_model ( $url, $model [, %args] ) >>

Retrieves the content from C<< $url >> and attempts to parse the resulting RDF
into C<< $model >> using a parser chosen by the associated content media type.

If C<< %args >> contains a C<< 'content_cb' >> key with a CODE reference value,
that callback function will be called after a successful response as:

 $content_cb->( $url, $content, $http_response_object )

If C<< %args >> contains a C<< 'useragent' >> key with a LWP::UserAgent object value,
that object is used to retrieve the requested URL without any configuration (such as
setting the Accept: header) which would ordinarily take place. Otherwise, the default
user agent (L<RDF::Trine/default_useragent>) is cloned and configured to retrieve
content that will be acceptable to any available parser.

=cut

sub parse_url_into_model {
	my $class	= shift;
	my $url		= shift;
	my $model	= shift;
	my %args	= @_;
	
	my $base	= $url;
	if (defined($args{base})) {
		$base	= $args{base};
	}
	
	my $ua;
	if (defined($args{useragent})) {
		$ua	= $args{useragent};
	} else {
		$ua		= RDF::Trine->default_useragent->clone;
		my $accept	= $class->default_accept_header;
		$ua->default_headers->push_header( 'Accept' => $accept );
	}
	
	my $resp	= $ua->get( $url );
	if ($url =~ /^file:/) {
		my $type	= guess_media_type($url);
		$resp->header('Content-Type', $type);
	}
	
	unless ($resp->is_success) {
		throw RDF::Trine::Error::ParserError -text => $resp->status_line;
	}
	
	my $content	= $resp->content;
	if (my $cb = $args{content_cb}) {
		$cb->( $url, $content, $resp );
	}
	
	my $type	= $resp->header('content-type');
	$type		=~ s/^([^\s;]+).*/$1/;
	my $pclass	= $media_types{ $type };
	if ($pclass and $pclass->can('new')) {
		my $data	= $content;
		if (my $e = $encodings{ $pclass }) {
			$data	= decode( $e, $content );
		}
		
		# pass %args in here too so the constructor can take its pick
		my $parser	= $pclass->new(%args);
		my $ok	= 0;
		try {
			$parser->parse_into_model( $base, $data, $model, %args );
			$ok	= 1;
		} catch RDF::Trine::Error with {};
		return 1 if ($ok);
	}
	
	### FALLBACK
	my %options;
	if (defined $args{canonicalize}) {
		$options{ canonicalize }	= $args{canonicalize};
	}
	
	my $ok	= 0;
	try {
		if ($url =~ /[.](x?rdf|owl)$/ or $content =~ m/\x{FEFF}?<[?]xml /smo) {
			my $parser	= RDF::Trine::Parser::RDFXML->new(%options);
			$parser->parse_into_model( $base, $content, $model, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]ttl$/ or $content =~ m/@(prefix|base)/smo) {
			my $parser	= RDF::Trine::Parser::Turtle->new(%options);
			my $data	= decode('utf8', $content);
			$parser->parse_into_model( $base, $data, $model, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]trig$/) {
			my $parser	= RDF::Trine::Parser::Trig->new(%options);
			my $data	= decode('utf8', $content);
			$parser->parse_into_model( $base, $data, $model, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]nt$/) {
			my $parser	= RDF::Trine::Parser::NTriples->new(%options);
			$parser->parse_into_model( $base, $content, $model, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]nq$/) {
			my $parser	= RDF::Trine::Parser::NQuads->new(%options);
			$parser->parse_into_model( $base, $content, $model, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]js(?:on)?$/) {
			my $parser	= RDF::Trine::Parser::RDFJSON->new(%options);
			$parser->parse_into_model( $base, $content, $model, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]x?html?$/) {
			my $parser	= RDF::Trine::Parser::RDFa->new(%options);
			$parser->parse_into_model( $base, $content, $model, %args );
			$ok	= 1;;
		} else {
			my @types	= keys %{ { map { $_ => 1 } values %media_types } };
			foreach my $pclass (@types) {
				my $data	= $content;
				if (my $e = $encodings{ $pclass }) {
					$data	= decode( $e, $content );
				}
				my $parser	= $pclass->new(%options);
				my $ok		= 0;
				try {
					$parser->parse_into_model( $base, $data, $model, %args );
					$ok	= 1;
				} catch RDF::Trine::Error::ParserError with {};
				last if ($ok);
			}
		}
	} catch RDF::Trine::Error with {
		my $e	= shift;
	};
	return 1 if ($ok);
	
	if ($pclass) {
		throw RDF::Trine::Error::ParserError -text => "Failed to parse data of type $type from $url";
	} else {
		throw RDF::Trine::Error::ParserError -text => "Failed to parse data from $url";
	}
}

=item C<< parse_url ( $url, \&handler [, %args] ) >>

Retrieves the content from C<< $url >> and attempts to parse the resulting RDF.
For each parsed RDF triple that is parsed, C<&handler> will be called with the
triple as an argument. Otherwise, this method acts just like
C<parse_url_into_model>.

=cut

sub parse_url {
	my $class	= shift;
	my $url		= shift;
	my $handler	= shift;
	my %args	= @_;
	
	my $base	= $url;
	if (defined($args{base})) {
		$base	= $args{base};
	}
	
	my $ua;
	if (defined($args{useragent})) {
		$ua	= $args{useragent};
	} else {
		$ua		= RDF::Trine->default_useragent->clone;
		my $accept	= $class->default_accept_header;
		$ua->default_headers->push_header( 'Accept' => $accept );
	}
	
	my $resp	= $ua->get( $url );
	if ($url =~ /^file:/) {
		my $type	= guess_media_type($url);
		$resp->header('Content-Type', $type);
	}
	
	unless ($resp->is_success) {
		throw RDF::Trine::Error::ParserError -text => $resp->status_line;
	}
	
	my $content	= $resp->content;
	if (my $cb = $args{content_cb}) {
		$cb->( $url, $content, $resp );
	}
	
	my $type	= $resp->header('content-type');
	$type		=~ s/^([^\s;]+).*/$1/;
	my $pclass	= $media_types{ $type };
	if ($pclass and $pclass->can('new')) {
		my $data	= $content;
		if (my $e = $encodings{ $pclass }) {
			$data	= decode( $e, $content );
		}
		
		# pass %args in here too so the constructor can take its pick
		my $parser	= $pclass->new(%args);
		my $ok	= 0;
		try {
			$parser->parse( $base, $data, $handler );
			$ok	= 1;
		} catch RDF::Trine::Error with {};
		return 1 if ($ok);
	}
	
	### FALLBACK
	my %options;
	if (defined $args{canonicalize}) {
		$options{ canonicalize }	= $args{canonicalize};
	}
	
	my $ok	= 0;
	try {
		if ($url =~ /[.](x?rdf|owl)$/ or $content =~ m/\x{FEFF}?<[?]xml /smo) {
			my $parser	= RDF::Trine::Parser::RDFXML->new(%options);
			$parser->parse( $base, $content, $handler, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]ttl$/ or $content =~ m/@(prefix|base)/smo) {
			my $parser	= RDF::Trine::Parser::Turtle->new(%options);
			my $data	= decode('utf8', $content);
			$parser->parse( $base, $data, $handler, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]trig$/) {
			my $parser	= RDF::Trine::Parser::Trig->new(%options);
			my $data	= decode('utf8', $content);
			$parser->parse( $base, $data, $handler, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]nt$/) {
			my $parser	= RDF::Trine::Parser::NTriples->new(%options);
			$parser->parse( $base, $content, $handler, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]nq$/) {
			my $parser	= RDF::Trine::Parser::NQuads->new(%options);
			$parser->parse( $base, $content, $handler, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]js(?:on)?$/) {
			my $parser	= RDF::Trine::Parser::RDFJSON->new(%options);
			$parser->parse( $base, $content, $handler, %args );
			$ok	= 1;;
		} elsif ($url =~ /[.]x?html?$/) {
			my $parser	= RDF::Trine::Parser::RDFa->new(%options);
			$parser->parse( $base, $content, $handler, %args );
			$ok	= 1;;
		} else {
			my @types	= keys %{ { map { $_ => 1 } values %media_types } };
			foreach my $pclass (@types) {
				my $data	= $content;
				if (my $e = $encodings{ $pclass }) {
					$data	= decode( $e, $content );
				}
				my $parser	= $pclass->new(%options);
				my $ok		= 0;
				try {
					$parser->parse( $base, $data, $handler, %args );
					$ok	= 1;
				} catch RDF::Trine::Error::ParserError with {};
				last if ($ok);
			}
		}
	} catch RDF::Trine::Error with {
		my $e	= shift;
	};
	return 1 if ($ok);
	
	if ($pclass) {
		throw RDF::Trine::Error::ParserError -text => "Failed to parse data of type $type from $url";
	} else {
		throw RDF::Trine::Error::ParserError -text => "Failed to parse data from $url";
	}
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the bytes in C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

sub parse_into_model {
	my $proto	= shift;
	my $self	= blessed($proto) ? $proto : $proto->new();
	my $uri		= shift;
	if (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= $uri->uri_value;
	}
	my $input	= shift;
	my $model	= shift;
	my %args	= @_;
	my $context	= $args{'context'};
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	
	$model->begin_bulk_ops();
	my $s	= $self->parse( $uri, $input, $handler );
	$model->end_bulk_ops();
	return $s;
}

=item C<< parse_file_into_model ( $base_uri, $fh, $model [, context => $context] ) >>

Parses all data read from the filehandle or file C<< $fh >>, using the 
given C<< $base_uri >>. For each RDF statement parsed, will call
C<< $model->add_statement( $statement ) >>.

=cut

sub parse_file_into_model {
	my $proto	= shift;
	my $self	= (blessed($proto) or $proto eq  __PACKAGE__)
			? $proto : $proto->new();
	my $uri		= shift;
	if (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= $uri->uri_value;
	}
	my $fh		= shift;
	my $model	= shift;
	my %args	= @_;
	my $context	= $args{'context'};
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	
	$model->begin_bulk_ops();
	my $s	= $self->parse_file( $uri, $fh, $handler );
	$model->end_bulk_ops();
	return $s;
}

=item C<< parse_file ( $base_uri, $fh, $handler ) >>

Parses all data read from the filehandle or file C<< $fh >>, using the given
C<< $base_uri >>. If C<< $fh >> is a filename, this method can guess the
associated parse. For each RDF statement parsed, C<< $handler->( $st ) >> is called.

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;

	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		unless ($self->can('parse')) {
			my $pclass = $self->guess_parser_by_filename( $filename );
			$self = $pclass->new() if ($pclass and $pclass->can('new'));
		}
		open( $fh, '<:encoding(UTF-8)', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}

	if ($self and $self->can('parse')) {
		my $content	= do { local($/) = undef; <$fh> };
		return $self->parse( $base, $content, $handler, @_ );
	} else {
		throw RDF::Trine::Error::ParserError -text => "Cannot parse unknown serialization";
	}
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut


=item C<< new_bnode_prefix () >>

Returns a new prefix to be used in the construction of blank node identifiers.
If either Data::UUID or UUID::Tiny are available, they are used to construct
a globally unique bnode prefix. Otherwise, an empty string is returned.

=cut

sub new_bnode_prefix {
	my $class	= shift;
	if (defined($Data::UUID::VERSION)) {
		my $ug		= new Data::UUID;
		my $uuid	= $ug->to_string( $ug->create() );
		$uuid		=~ s/-//g;
		return 'b' . $uuid;
	} elsif (defined($UUID::Tiny::VERSION) && ($] < 5.010000)) { # UUID::Tiny 1.03 isn't working nice with thread support in Perl 5.14. When this is fixed, this may be removed and dep added.
		my $uuid	= UUID::Tiny::create_UUID_as_string(UUID::Tiny::UUID_V1());
		$uuid		=~ s/-//g;
		return 'b' . $uuid;
	} else {
		return '';
	}
}

=item C<< default_accept_header >>

Returns the default HTTP Accept header value used in requesting RDF content (e.g. in
L</parse_url_into_model>) that may be parsed by one of the available RDF::Trine::Parser
subclasses.

By default, RDF/XML and Turtle are preferred over other media types.

=cut

sub default_accept_header {
	# prefer RDF/XML or Turtle, then anything else that we've got a parser for.
	my $accept	= join(',', map { /(turtle|rdf[+]xml)/ ? "$_;q=1.0" : "$_;q=0.9" } keys %media_types);
	return $accept;
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
