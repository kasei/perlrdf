use strict;
use warnings;

use inc::Module::Install;

name				'RDF-Query';
all_from			'lib/RDF/Query.pm';
author				'Gregory Todd Williams <gwilliams@cpan.org>';
license				'perl';

recommends			'LWP::Simple'				=> 0;
recommends			'Getopt::Simple'			=> 0;
recommends			'Geo::Distance'				=> 0.09;

build_requires		'Test::JSON'				=> 0;
build_requires		'Test::More'				=> 0.88;
build_requires		'Test::Exception'			=> 0;
build_requires		'YAML'						=> 0;
build_requires		'FindBin'					=> 0;

requires			'Module::Pluggable'			=> 0;
requires			'Data::UUID'				=> 0;
requires			'Digest::SHA'				=> 0;
requires			'DateTime::Format::W3CDTF'	=> 0;
requires			'Error'						=> 0;
requires			'File::Spec'				=> 0;
requires			'File::Temp'				=> 0;
requires			'JSON'						=> 2;
requires			'Parse::RecDescent'			=> 0;
requires			'RDF::Trine'				=> 1.003;
requires			'Scalar::Util'				=> 0;
requires			'Set::Scalar'				=> 0;
requires			'URI'						=> 1.52;
requires			'I18N::LangTags'			=> 0;

resources(
	'homepage'   => "http://search.cpan.org/dist/RDF-Query/",
	'repository' => "http://github.com/kasei/perlrdf/",
	'bugtracker' => "https://github.com/kasei/perlrdf/issues"
);

author_tests('xt');

install_script 'bin/rqsh';

sign;

WriteAll;
