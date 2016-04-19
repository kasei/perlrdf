#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 30;

use utf8;

use RDF::Trine qw(literal);
use RDF::Trine::Namespace qw(xsd);

ok( literal('0', undef, $xsd->integer)->is_valid_lexical_form, 'integer valid lexical form' );
ok( literal('1', undef, $xsd->integer)->is_valid_lexical_form, 'integer valid lexical form' );
ok( literal('01', undef, $xsd->integer)->is_valid_lexical_form, 'integer valid lexical form' );
ok( not(literal('02 ', undef, $xsd->integer)->is_valid_lexical_form), 'integer valid lexical form' );
ok( not(literal('abc', undef, $xsd->integer)->is_valid_lexical_form), 'integer valid lexical form' );

my %values	= (
	integer	=> {
		'01'	=> '1',
		'+1'	=> '1',
		'-01'	=> '-1',
	},
	decimal	=> {
		'0.00'	=> '0.0',
		'+01.10'	=> '1.1',
	},
	float	=> {
		'-1E4'	=> '-1.0E4',
		'-1e4'	=> '-1.0E4',
		'+1e+01'	=> '1.0E1',
		'1e+000'	=> '1.0E0',
		'-INF'	=> '-INF',
		'+INF'	=> 'INF',
		'NaN'	=> 'NaN',
		'12.78e-2'	=> '1.278E-1',
	},
	double	=> {
		'-1E4'	=> '-1.0E4',
		'-1e4'	=> '-1.0E4',
		'+1e+01'	=> '1.0E1',
		'1e+000'	=> '1.0E0',
		'-INF'	=> '-INF',
		'+INF'	=> 'INF',
		'NaN'	=> 'NaN',
		'12.78e-2'	=> '1.278E-1',
	},
	boolean	=> {
		'true'	=> 'true',
		'1'		=> 'true',
		'false'	=> 'false',
		'0'		=> 'false',
	},
);

foreach my $type (keys %values) {
	while (my($k,$v) = each(%{ $values{$type} })) {
		my $canon	= literal($k, undef, $xsd->$type(), 1);
		is( $canon->literal_value, $v, "canonicalization of xsd:$type" );
	}
}


__END__
