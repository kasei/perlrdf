use strict;
use warnings;
no warnings 'redefine';

# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'Test::JSON'				=> 0;

WriteMakefile(
    NAME				=> 'RDF::Trine',
    VERSION_FROM		=> 'lib/RDF/Trine.pm',
    ABSTRACT_FROM		=> 'lib/RDF/Trine.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    PREREQ_PM			=> {
					'Data::UUID'				=> 0,
					'DBI'						=> 0,
					'DBD::SQLite'				=> 1.14,
					'Digest::MD5'				=> 0,
					'Digest::SHA1'				=> 0,
					'Error'						=> 0,
					'HTTP::Negotiate'			=> 0,
					'JSON'						=> 2,
					'LWP::UserAgent'			=> 0,
					'List::Util'				=> 0,
					'List::MoreUtils'			=> 0,
					'Log::Log4perl'				=> 0,
					'Math::BigInt'				=> 0,
					'Math::Combinatorics'		=> 0.09,
					'Scalar::Util'				=> 0,
					'Set::Scalar'				=> 0,
					'Storable'					=> 0,
					'Text::CSV'					=> 0,
					'Text::Table'				=> 0,
					'Time::HiRes'				=> 0,
					'Unicode::Escape'			=> 0,
					'Unicode::String'			=> 2.09,
					'URI'						=> 0,
					'XML::CommonNS'				=> 0.04,
					'XML::Namespace'			=> 0,
					'XML::SAX'					=> 0,
					'XML::LibXML::SAX'			=> 1.66,	# we shouldn't need this, but XML::SAX::PurePerl seems to have some major bugs with unicode in some of the RDF/XML syntax examples
				},
);
