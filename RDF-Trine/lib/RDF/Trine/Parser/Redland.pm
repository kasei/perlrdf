# RDF::Trine::Parser::Redland
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::Redland - RDFa Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFa version 0.130

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 use RDF::Trine::Parser::Redland; # to overwrite internal dispatcher

 # Redland does turtle, ntriples, trig and rdfa as well
 my $parser = RDF::Trine::Parser->new( 'rdfxml' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::Redland;

use strict;
use warnings;

use base qw(RDF::Trine::Parser);

use Carp;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);

use RDF::Trine qw(literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION, $HAVE_REDLAND_PARSER, %FORMATS);
BEGIN {
	%FORMATS = (
	rdfxml	 => ['http://www.w3.org/ns/formats/RDF_XML',
					[qw(application/rdf+xml)]],
	ntriples => ['http://www.w3.org/ns/formats/data/N-Triples',
					[qw(text/plain)]],
	turtle	 => ['http://www.w3.org/ns/formats/Turtle',
					 [qw(application/x-turtle application/turtle text/turtle)]],
	trig	 => [undef, []],
	rdfa	 => ['http://www.w3.org/ns/formats/data/RDFa',
					 [qw(application/xhtml+xml)]]
	);
	
	$VERSION	= '0.130';
	for my $format (keys %FORMATS) {
		$RDF::Trine::Parser::parser_names{$format} = __PACKAGE__;
		$RDF::Trine::Parser::format_uris{ $FORMATS{$format}[0] } = __PACKAGE__
			if defined $FORMATS{$format}[0];
		map { $RDF::Trine::Parser::media_types{$_} = __PACKAGE__ }
			(@{$FORMATS{$format}[1]});
	}
	
	eval "use RDF::Redland 1.000701;";
	unless ($@) {
		$HAVE_REDLAND_PARSER	= 1;
	}
}

######################################################################

=item C<< new ( options => \%options ) >>

Returns a new Redland parser object with the supplied options. Use the
C<name> option to tell Redland which parser it should use.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	unless ($HAVE_REDLAND_PARSER) {
		throw RDF::Trine::Error
			-text => "Failed to load RDF::Redland >= 1.0.7.1";
	}
	unless (defined $args{name}) {
		throw RDF::Trine::Error
			-text => "Redland parser needs to know which format it's parsing!";
	}
	unless ($FORMATS{$args{name}}) {
		throw RDF::Trine::Error
			-text => "Unrecognized format name $args{name} for Redland parser";
	}
	$args{parser} = RDF::Redland::Parser->new($args{name}) or
		throw RDF::Trine::Error
			-text => "Could not load a Redland $args{name} parser.";

	#warn "sup dawgs";

	my $self = bless( { %args }, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler = shift;
	
	my $null_base	= 'urn:uuid:1d1e755d-c622-4610-bae8-40261157687b';
	$base		= RDF::Redland::URI->new(defined $base ? $base : $null_base);
	my $stream	= eval {
		$self->{parser}->parse_string_as_stream($string, $base)
	};
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => $@;
	}
	
	while ($stream and !$stream->end) {
		#my $context = $stream->context;
		#warn $context;
		my $stmt = RDF::Trine::Statement->from_redland($stream->current);
		if ($self->{canonicalize}) {
			my $o = $stmt->object;
			# basically copied from RDF::Trine::Parser::Turtle
			if ($o->isa('RDF::Trine::Node::Literal') and $o->has_datatype) {
				my $value	= $o->literal_value;
				my $dt		= $o->literal_datatype;
				my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
				$o	= literal( $canon, undef, $dt );

				$stmt->object($o);
			}
		}

		# run handler
		$handler->($stmt) if ($handler and reftype($handler) eq 'CODE');

		$stream->next;
	}
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
