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
    VERSION_FROM		=> 'lib/RDF/Trine.pm',
    ABSTRACT_FROM		=> 'lib/RDF/Trine.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    PREREQ_PM			=> {
					'Bloom::Filter'				=> 0,
					'Data::UUID'				=> 0,
					'DBI'						=> 0,
					'DBD::SQLite'				=> 1.14,
					'Digest::MD5'				=> 0,
					'Error'						=> 0,
					'JSON'						=> 2,
					'LWP::UserAgent'			=> 0,
					'List::MoreUtils'			=> 0,
					'List::Util'				=> 0,
					'Math::BigInt'				=> 0,
					'Scalar::Util'				=> 0,
					'Time::HiRes'				=> 0,
					'Unicode::Escape'			=> 0,
					'URI'						=> 0,
					'XML::CommonNS'				=> 0.04,
					'XML::Namespace'			=> 0,
					'XML::SAX'					=> 0,
				},
);
