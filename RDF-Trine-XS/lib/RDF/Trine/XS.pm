package RDF::Trine::XS;

use strict;
use warnings;

use XSLoader;
use Digest::MD5 ('md5');

our $VERSION = '2.000_01';
XSLoader::load "RDF::Trine::XS", $VERSION;

sub hash {
	my $value	= shift;
	my $md5		= md5( $value );
	return _hash( $md5 );
}

1;
