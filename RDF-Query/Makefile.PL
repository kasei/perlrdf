use strict;
use warnings;

use inc::Module::Install;

name				'RDF-Query';
all_from			'lib/RDF/Query.pm';
author				'Gregory Todd Williams <gwilliams@cpan.org>';
license				'perl';

recommends			'LWP::Simple'				=> 0;
recommends			'RDF::Redland'				=> 1;
recommends			'Getopt::Simple'			=> 0;
recommends			'Geo::Distance'				=> 0.09;
recommends			'Crypt::GPG'				=> 0;
recommends			'Bloom::Filter'				=> 1;

build_requires		'Test::JSON'				=> 0;
build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'YAML'						=> 0;
build_requires		'FindBin'					=> 0;

requires			'Data::UUID'				=> 0;
requires			'Digest::SHA1'				=> 0;
requires			'DateTime::Format::W3CDTF'	=> 0;
requires			'Error'						=> 0;
requires			'File::Spec'				=> 0;
requires			'File::Temp'				=> 0;
requires			'JSON'						=> 2;
requires			'Parse::RecDescent'			=> 0;
requires			'RDF::Trine'				=> 0.125;
requires			'Scalar::Util'				=> 0;
requires			'Set::Scalar'				=> 0;
requires			'URI'						=> 0;
requires			'I18N::LangTags'			=> 0;

resources(
	'homepage'   => "http://search.cpan.org/dist/RDF-Query/",
	'repository' => "http://github.com/kasei/perlrdf/",
);

author_tests('xt');

sign;

WriteAll;
