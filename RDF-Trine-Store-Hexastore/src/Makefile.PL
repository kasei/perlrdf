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
    NAME                		=> 'RDF::Trine::Store::HexastoreXS',
	AUTHOR						=> 'Gregory Todd Williams <gwilliams@cpan.org>',
	CCFLAGS						=> '-std=c99 -arch i386 -arch ppc -arch ppc64 -arch x86_64',
    VERSION_FROM        		=> 'lib/RDF/Trine/Store/HexastoreXS.pm',
    ABSTRACT_FROM       		=> 'lib/RDF/Trine/Store/HexastoreXS.pm',
    LIBS						=> ['-lraptor -lcrypto'],
    OBJECT						=> 'hexastore.o avl.o index.o head.o vector.o terminal.o HexastoreXS.o',
);
