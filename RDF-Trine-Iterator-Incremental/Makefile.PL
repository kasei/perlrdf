use strict;
use warnings;
no warnings 'redefine';

# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

recommends			'XML::SAX::Expat::Incremental'	=> 0;

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;

WriteMakefile(
    NAME				=> 'RDF::Trine::Iterator::Incremental',
    VERSION_FROM		=> 'lib/RDF/Trine/Iterator/Incremental.pm',
    ABSTRACT_FROM		=> 'lib/RDF/Trine/Iterator/Incremental.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    PREREQ_PM			=> {
					'RDF::Trine::Iterator'			=> 0.109,
					'XML::SAX::Expat::Incremental'	=> 0,
					'Log::Log4perl'					=> 0,
				},
);
