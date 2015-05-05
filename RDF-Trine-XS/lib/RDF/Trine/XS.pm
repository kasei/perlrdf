package RDF::Trine::XS;

use strict;
use warnings;

use XSLoader;
use Digest::MD5 ('md5');
use Encode;

our $VERSION = '2.000_01';
XSLoader::load "RDF::Trine::XS", $VERSION;

sub hash {
	if (ref($_[0])) {
		my $self = shift;
	}
	my $value	= shift;
	my $md5		= md5( encode('utf8', $value) );
	return _hash( $md5 );
}

1;
