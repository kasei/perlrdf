# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class

=head1 VERSION

This document describes RDF::Trine::Parser version 0.124

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

our ($VERSION);
our %parser_names;
our %media_types;
our %format_uris;
our %encodings;
BEGIN {
	$VERSION	= '0.124';
}

use Scalar::Util qw(blessed);
use LWP::UserAgent;

use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser::NTriples;
use RDF::Trine::Parser::NQuads;
use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::TriG;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Parser::RDFJSON;
use RDF::Trine::Parser::RDFa;

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
		return $class->new( @_ );
	} else {
		throw RDF::Trine::Error::ParserError -text => "No parser known named $name";
	}
}

=item C<< parse_url_into_model ( $url, $model [, %args] ) >>

Retrieves the content from C<< $url >> and attempts to parse the resulting RDF
into C<< $model >> using a parser chosen by the associated content media type.

=cut

sub parse_url_into_model {
	my $class	= shift;
	my $url		= shift;
	my $model	= shift;
	my %args	= @_;
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Trine/$RDF::Trine::VERSION" );
	
	# prefer RDF/XML or Turtle, then anything else that we've got a parser for.
	my $accept	= join(',', map { /(turtle|rdf[+]xml)/ ? "$_;q=1.0" : "$_;q=0.9" } keys %media_types);
	$ua->default_headers->push_header( 'Accept' => $accept );
	
	my $resp	= $ua->get( $url );
	unless ($resp->is_success) {
		throw RDF::Trine::Error::ParserError -text => $resp->status_line;
	}
	
	my $content	= $resp->content;
	my $type	= $resp->header('content-type');
	$type		=~ s/^([^\s;]+).*/$1/;
	my $pclass	= $media_types{ $type };
	if ($pclass and $pclass->can('new')) {
		my $data	= $content;
		if (my $e = $encodings{ $pclass }) {
			$data	= decode( $e, $content );
		}
		my $parser	= $pclass->new();
		my $ok		= 0;
		try {
			$parser->parse_into_model( $url, $data, $model, %args );
			$ok	= 1;
		} catch RDF::Trine::Error::ParserError with {} otherwise {};
		return 1 if ($ok);
	} else {
		throw RDF::Trine::Error::ParserError -text => "No parser found for content type $type";
	}
	
	### FALLBACK
	if ($url =~ /[.]x?rdf$/) {
		my $parser	= RDF::Trine::Parser::RDFXML->new();
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} elsif ($url =~ /[.]ttl/) {
		my $parser	= RDF::Trine::Parser::Turtle->new();
		my $data	= decode('utf8', $content);
		$parser->parse_into_model( $url, $data, $model, %args );
		return 1;
	} elsif ($url =~ /[.]nt/) {
		my $parser	= RDF::Trine::Parser::NTriples->new();
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} elsif ($url =~ /[.]x?html/) {
		my $parser	= RDF::Trine::Parser::RDFa->new();
		$parser->parse_into_model( $url, $content, $model, %args );
		return 1;
	} else {
		my @types	= keys %{ { map { $_ => 1 } values %media_types } };
		foreach my $pclass (@types) {
			my $data	= $content;
			if (my $e = $encodings{ $pclass }) {
				$data	= decode( $e, $content );
			}
			my $parser	= $pclass->new();
			my $ok		= 0;
			try {
				$parser->parse_into_model( $url, $data, $model, %args );
				$ok	= 1;
			} catch RDF::Trine::Error::ParserError with {};
			return 1 if ($ok);
		}
	}
	throw RDF::Trine::Error::ParserError -text => "Failed to parse data from $url";
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF
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
	return $self->parse( $uri, $input, $handler );
}

=item C<< parse_file_into_model ( $base_uri, $fh, $model [, context => $context] ) >>

Parses all data read from the filehandle C<< $fh >>, using the given
C<< $base_uri >>. For each RDF statement parsed, will call
C<< $model->add_statement( $statement ) >>.

=cut

sub parse_file_into_model {
	my $proto	= shift;
	my $self	= blessed($proto) ? $proto : $proto->new();
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
	return $self->parse_file( $uri, $fh, $handler );
}

=item C<< parse_file ( $base, $fh, $handler ) >>

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;
	
	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		open( $fh, '<', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	my $content	= do { local($/) = undef; <$fh> };
	return $self->parse( $base, $content, $handler, @_ );
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

=cut


=item C<< canonicalize_literal_value ( $string, $datatype ) >>

If C<< $datatype >> is a recognized datatype, returns the canonical lexical
representation of the value C<< $string >>. Otherwise returns C<< $string >>.

Currently, xsd:integer, xsd:decimal, and xsd:boolean are canonicalized.
Additionaly, invalid lexical forms for xsd:float, xsd:double, and xsd:dateTime
will trigger a warning.

=cut

sub canonicalize_literal_value {
	my $self	= shift;
	my $value	= shift;
	my $dt		= shift;
	if ($dt eq 'http://www.w3.org/2001/XMLSchema#integer') {
		if ($value =~ m/^([-+])?(\d+)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} else {
			warn "Bad lexical form for xsd:integer: '$value'";
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)([.]\d*)?)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			my $int		= $3;
			my $frac	= $4;
			$sign		= '' if ($sign eq '+');
			unless ($frac =~ m/[1-9]/) {
				$num	= $int;
			}
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} else {
			warn "Bad lexical form for xsd:deciaml: '$value'";
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return $value;
		} else {
			warn "Bad lexical form for xsd:float: '$value'";
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)? |[-+]?INF|NaN$/) {
			return $value;
		} else {
			warn "Bad lexical form for xsd:double: '$value'";
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false|0|1)$/) {
			$value	= 'true' if ($value eq '1');
			$value	= 'false' if ($value eq '0');
			return $value;
		} else {
			warn "Bad lexical form for xsd:boolean: '$value'";
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			# XXX need to canonicalize the dateTime
			return $value;
		} else {
			warn "Bad lexical form for xsd:boolean: '$value'";
		}
	}
	return $value;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
