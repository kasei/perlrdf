use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'RDF::Namespace',
    AUTHOR              => 'Gregory Todd Williams <greg@evilfunhouse.com>',
    VERSION_FROM        => 'lib/RDF/Namespace.pm',
    ABSTRACT_FROM       => 'lib/RDF/Namespace.pm',
    PL_FILES            => {},
    PREREQ_PM => {
    	'RDF::Query::Node'	=> 0,
    	'XML::Namespace'	=> 0,
    	'XML::CommonNS'		=> 0.04,
        'Test::More' 		=> 0,
    },
    LICENSE				=> 'perl',
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'RDF-Namespace-*' },
);
