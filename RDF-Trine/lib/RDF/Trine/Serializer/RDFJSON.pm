# RDF::Trine::Serializer::RDFJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::RDFJSON - RDF/JSON Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::RDF/JSON version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Serializer::RDFJSON;
 my $serializer	= RDF::Trine::Serializer::RDFJSON->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::Turtle class provides an API for serializing RDF
graphs to the RDF/JSON syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::RDFJSON;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use JSON;
use Data::Dumper;
use Scalar::Util qw(blessed);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
	$RDF::Trine::Serializer::serializer_names{ 'rdfjson' }	= __PACKAGE__;
	foreach my $type (qw(application/json application/x-rdf+json)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

Returns a new serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $file, $model [,\%json_options] ) >>

Serializes the C<$model> to RDF/JSON, printing the results to the supplied
C<$file> handle.

C<%json_options> is an options hash suitable for JSON::to_json.

=cut

sub serialize_model_to_file {
	my $self	  = shift;
	my $file	  = shift;
	my $model  = shift;
	my $opts   = shift;
	my $string = to_json($model->as_hashref, $opts);
	print {$file} $string;
}

=item C<< serialize_model_to_string ( $model [,\%json_options] ) >>

Serializes the C<$model> to RDF/JSON, returning the result as a string.

C<%json_options> is an options hash suitable for JSON::to_json.

=cut

sub serialize_model_to_string {
	my $self	  = shift;
	my $model  = shift;
	my $opts   = shift;
	my $string = to_json($model->as_hashref, $opts);
	return $string;
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://n2.talis.com/wiki/RDF_JSON_Specification>

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010 Toby Inkster. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

