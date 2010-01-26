use strict;
use warnings;
no warnings 'redefine';

# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

build_requires		'File::Temp'				=> 0;
build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'Test::MockObject'			=> 0;

WriteMakefile(
	NAME				=> 'RDF::LinkedData::Apache',
	ABSTRACT			=> 'A mod_perl handler class for serving RDF as linked data.',
	VERSION_FROM		=> 'lib/RDF/LinkedData/Apache.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
	PREREQ_PM			=> {
					'Apache2::Const'		=> 0,
					'Apache2::Request'		=> 0,
					'Apache2::RequestRec'	=> 0,
					'Apache2::RequestUtil'	=> 0,
					'Error'					=> 0,
					'HTTP::Negotiate'		=> 0,
					'RDF::Trine'			=> 0.114,
					'Scalar::Util'			=> 0,
					'URI::Escape'			=> 0,
				},
);
