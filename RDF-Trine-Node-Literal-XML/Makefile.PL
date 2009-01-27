use strict;
use warnings;

use inc::Module::Install;

license				'perl';

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;

#####################################################

WriteMakefile(
    NAME                		=> 'RDF::Trine::XS',
	AUTHOR						=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    VERSION_FROM        		=> 'lib/RDF/Trine/Node/Literal/XML.pm',
    ABSTRACT_FROM       		=> 'lib/RDF/Trine/Node/Literal/XML.pm',
    PREREQ_PM			=> {
					'RDF::Trine'				=> 0,
					'Scalar::Util'				=> 0,
					'XML::LibXML'				=> 0,
					'Error'						=> 0,
				},
);
