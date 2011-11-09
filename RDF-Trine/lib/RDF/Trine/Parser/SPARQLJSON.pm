# RDF::Trine::Parser::SPARQLJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::SPARQLJSON - SPARQL JSON Results Format Parser

=head1 VERSION

This document describes RDF::Trine::Parser::SPARQLJSON version 0.136

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'SPARQL/JSON' );
 $parser->parse_bindings_string( $json );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::SPARQLJSON;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';

use URI;
use Log::Log4perl;

use RDF::Trine qw(literal);
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Error qw(:try);

use Scalar::Util qw(blessed looks_like_number);
use JSON;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION				= '0.136';
}
use RDF::Trine::Parser -base => {
	parser_names    => [qw{sparqljson}],
	format_uris     => ['http://www.w3.org/ns/formats/SPARQL_Results_JSON'],
	file_extensions => [qw{srj}],
	media_types     => [qw{application/sparql-results+json}],
	content_classes	=> [qw(RDF::Trine::Iterator::Bindings)],
};

######################################################################

=item C<< new >>

Returns a new SPARQLJSON parser.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	return bless(\%args, $class);
}

=item C<< parse_bindings_string ( $json ) >>

Returns a RDF::Trine::Iterator object containing the data from the supplied JSON
in JSON SPARQL Results format.

=cut

sub parse_bindings_string {
	my $self	= shift;
	my $json	= shift;
	my $data	= eval { from_json($json, {utf8 => 1}) };
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => "JSON decoding failed (maybe a remote endpoint returned bad data?): $@";
	}
	my $head	= $data->{head};
	my $vars	= $head->{vars};
	my $res		= $data->{results};
	if (defined(my $bool = $data->{boolean})) {
		my $value	= ($bool) ? 1 : 0;
		return RDF::Trine::Iterator::Boolean->new([$value]);
	} elsif (my $binds = $res->{bindings}) {
		my @results;
		foreach my $b (@$binds) {
			my %data;
			foreach my $v (@$vars) {
				if (defined(my $value = $b->{ $v })) {
					my $type	= $value->{type};
					if ($type eq 'uri') {
						my $data	= $value->{value};
						$data{ $v }	= RDF::Trine::Node::Resource->new( $data );
					} elsif ($type eq 'bnode') {
						my $data	= $value->{value};
						$data{ $v }	= RDF::Trine::Node::Blank->new( $data );
					} elsif ($type eq 'literal') {
						my $data	= $value->{value};
						if (my $lang = $value->{'xml:lang'}) {
							$data{ $v }	= RDF::Trine::Node::Literal->new( $data, $lang );
						} else {
							$data{ $v }	= RDF::Trine::Node::Literal->new( $data );
						}
					} elsif ($type eq 'typed-literal') {
						my $data	= $value->{value};
						my $dt		= $value->{datatype};
						if ($self->{canonicalize}) {
							$data	= RDF::Trine::Node::Literal->canonicalize_literal_value( $data, $dt, 0 );
						}
						$data{ $v }	= RDF::Trine::Node::Literal->new( $data, undef, $dt );
					} else {
						warn Dumper($data, $b);
						throw RDF::Trine::Error -text => "Unknown node type $type during parsing of SPARQL JSON Results";
					}
				}
			}
			push(@results, RDF::Trine::VariableBindings->new( \%data ));
		}
		return RDF::Trine::Iterator::Bindings->new( \@results );
	}
	warn '*** ' . Dumper($data);
}

=item C<< parse_bindings_file ( $fh ) >>

Returns a RDF::Trine::Iterator object containing the data from the supplied
file handle in SPARQL JSON Results format.

=cut

sub parse_bindings_file {
	my $self	= shift;
	my $fh		= shift;
	my $string	= do { local($/) = undef; <$fh> };
	return $self->parse_bindings_string( $string );
}


1;

__END__

=back

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
