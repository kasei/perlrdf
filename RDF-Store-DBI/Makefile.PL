use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'RDF::Store::DBI',
    AUTHOR              => 'Gregory Todd Williams <gwilliams@cpan.org>',
    VERSION_FROM        => 'lib/RDF/Store/DBI.pm',
    ABSTRACT_FROM       => 'lib/RDF/Store/DBI.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'RDF-Store-DBI-*' },
);
