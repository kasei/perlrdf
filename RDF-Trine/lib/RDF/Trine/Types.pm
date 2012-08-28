package RDF::Trine::Types;

use MooseX::Types -declare => [qw(UriStr)];
use MooseX::Types::Moose -all;

subtype UriStr, as Str, where { m{^\S+$} };
coerce UriStr, from Object, via { $_->uri };


1;


