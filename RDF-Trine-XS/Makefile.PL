use strict;
use warnings;

use inc::Module::Install;

license				'perl';

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;

recommends			'ExtUtils::CBuilder'		=> 0;
recommends			'ExtUtils::ParseXS'			=> 0;
#####################################################

WriteMakefile(
    NAME                		=> 'RDF::Trine::XS',
	AUTHOR						=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    VERSION_FROM        		=> 'lib/RDF/Trine/XS.pm',
    ABSTRACT_FROM       		=> 'lib/RDF/Trine/XS.pm',
);
