use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'RDF::Trice',
    AUTHOR              => 'Gregory Todd Williams <greg@evilfunhouse.com>',
    VERSION_FROM        => 'lib/RDF/Trice.pm',
    ABSTRACT_FROM       => 'lib/RDF/Trice.pm',
    PL_FILES            => {},
    PREREQ_PM => {
		'XML::Namespace'			=> 0,
		'XML::CommonNS'				=> 0.04,
		'Error'						=> 0,
		'Unicode::Escape'			=> 0,
		'Scalar::Util'				=> 0,
		'URI'						=> 0,
		'Test::More' 				=> 0,
		'JSON'						=> 2,
    },
    LICENSE				=> 'perl',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'RDF-Trice-*' },
);
