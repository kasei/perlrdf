use strict;
use warnings;

use inc::Module::Install;

license				'perl';
build_requires		'Test::More'				=> 0.61;
build_requires		'Test::JSON'				=> 0;

WriteMakefile(
    NAME                => 'RDF::SPARQLResults',
    AUTHOR              => 'Gregory Todd Williams <greg@evilfunhouse.com>',
    VERSION_FROM        => 'lib/RDF/SPARQLResults.pm',
    ABSTRACT_FROM       => 'lib/RDF/SPARQLResults.pm',
    PREREQ_PM => {
        JSON			=> 0,
    },
);
