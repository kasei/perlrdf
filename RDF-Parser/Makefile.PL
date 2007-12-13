# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'FindBin'					=> 0;

WriteMakefile(
	NAME			=> 'RDF::Parser',
	ABSTRACT		=> 'A pure-perl impelmentation of RDF parsers for Turtle and RDF/XML.',
	VERSION_FROM	=> 'lib/RDF/Parser.pm',
	AUTHOR			=> 'Gregory Todd Williams <gwilliams@cpan.org>',
	PREREQ_PM		=> {
					'Error'						=> 0,
					'RDF::Namespace'			=> 0,
					'RDF::Query'				=> 0,
					'Unicode::Escape'			=> 0,
					'Scalar::Util'				=> 0,
					'URI'						=> 0,
				}
);
