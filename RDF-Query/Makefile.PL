use strict;
use warnings;
no warnings 'redefine';

# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

recommends			'LWP::Simple'				=> 0;
recommends			'RDF::Redland'				=> 1;
recommends			'JavaScript'				=> 0;
recommends			'Getopt::Simple'			=> 0;
recommends			'Geo::Distance'				=> 0.09;
recommends			'Crypt::GPG'				=> 0;
recommends			'Bloom::Filter'				=> 1;

build_requires		'Test::JSON'				=> 0;
build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'YAML'						=> 0;
build_requires		'FindBin'					=> 0;

WriteMakefile(
	NAME				=> 'RDF::Query',
	ABSTRACT			=> 'A pure-perl impelmentation of the RDF query languages SPARQL and RDQL.',
	VERSION_FROM		=> 'lib/RDF/Query.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
	PREREQ_PM			=> {
					'Digest::SHA1'				=> 0,
					'DateTime::Format::W3CDTF'	=> 0,
					'Error'						=> 0,
					'File::Spec'				=> 0,
					'File::Temp'				=> 0,
					'JSON'						=> 2,
					'List::MoreUtils'			=> 0,
					'Parse::RecDescent'			=> 0,
					'RDF::Core'					=> 0,
					'RDF::Trine'				=> 0.109,
					'Scalar::Util'				=> 0,
					'Scalar::Util'				=> 0,
					'Set::Scalar'				=> 0,
					'URI'						=> 0,
				},
);
