# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

recommends			'LWP::Simple'				=> 0;
recommends			'RDF::Redland'				=> 1;
recommends			'JavaScript'				=> 0;
recommends			'Getopt::Simple'			=> 0;
recommends			'Digest::SHA1'				=> 0;
recommends			'Geo::Distance'				=> 0.09;
recommends			'Crypt::GPG'				=> 0;

build_requires		'Test::JSON'				=> 0;
build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'YAML'						=> 0;
build_requires		'FindBin'					=> 0;

WriteMakefile(
	NAME			=> 'RDF::Query',
	ABSTRACT		=> 'A pure-perl impelmentation of the RDF query languages SPARQL and RDQL.',
	VERSION_FROM	=> 'lib/RDF/Query.pm',
	AUTHOR			=> 'Gregory Todd Williams <gwilliams@cpan.org>',
	PREREQ_PM		=> {
					'Storable'					=> 0,
					'RDF::Core'					=> 0,
					'RDF::Trine'				=> 1,
					'Parse::RecDescent'			=> 0,
					'DateTime::Format::W3CDTF'	=> 0,
					'Scalar::Util'				=> 0,
					'Error'						=> 0,
					'JSON'						=> 2,
					'URI'						=> 0,
					'List::MoreUtils'			=> 0,
					'RDF::Trine::Iterator'		=> 1,
					'Set::Scalar'				=> 0,
					'File::Spec'				=> 0,
					'File::Temp'				=> 0,
					'Scalar::Util'				=> 0,
				}
);
