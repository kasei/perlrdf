# RDF::Trine::Serializer::RDFJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::RDFJSON - RDF/JSON Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::RDF/JSON version 0.112_01

=head1 SYNOPSIS

 use RDF::Trine::Serializer::RDFJSON;
 my $serializer	= RDF::Trine::Serializer::RDFJSON->new();

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Serializer::RDFJSON;

use strict;
use warnings;

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
	$VERSION	= '0.112_01';
}

######################################################################

=item C<< new >>

Returns a new 

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	$class = ref($class) || $class;
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
	print {$file} $string . " .\n";
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

=head1 SEE ALSO

http://n2.talis.com/wiki/RDF_JSON_Specification

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=cut

