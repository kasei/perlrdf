use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'RDF::Trine',
    AUTHOR              => 'Gregory Todd Williams <greg@evilfunhouse.com>',
    VERSION_FROM        => 'lib/RDF/Trine.pm',
    ABSTRACT_FROM       => 'lib/RDF/Trine.pm',
    PL_FILES            => {},
    PREREQ_PM => {
    	'DBI'						=> 0,
    	'Digest::MD5'				=> 0,
		'Error'						=> 0,
		'JSON'						=> 2,
		'LWP::UserAgent'			=> 0,
		'List::MoreUtils'			=> 0,
		'List::Util:'				=> 0,
		'Math::BigInt'				=> 0,
		'Scalar::Util'				=> 0,
		'Test::More' 				=> 0,
		'Test::JSON'				=> 0,
		'Test::Exception'			=> 0,
		'Unicode::Escape'			=> 0,
		'URI'						=> 0,
		'XML::CommonNS'				=> 0.04,
		'XML::Namespace'			=> 0,
		'XML::Twig'					=> 0,
    },
    LICENSE				=> 'perl',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'RDF-Trine-*' },
);
