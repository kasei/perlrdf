use strict;
use warnings;
no warnings 'redefine';

# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

build_requires		'Test::JSON'				=> 0;
build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;

WriteMakefile(
    NAME				=> 'RDF::Trine',
    VERSION_FROM		=> 'lib/RDF/Trine/Store/Hexastore.pm',
    ABSTRACT_FROM		=> 'lib/RDF/Trine/Store/Hexastore.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    PREREQ_PM			=> {
					'RDF::Trine'				=> 0.109,
					'LWP::UserAgent'			=> 0,
					'List::MoreUtils'			=> 0,
					'List::Util'				=> 0,
					'Log::Log4perl'				=> 0,
					'Scalar::Util'				=> 0,
				},
);
