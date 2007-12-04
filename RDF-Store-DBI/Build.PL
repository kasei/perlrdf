use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'RDF::Store::DBI',
    license             => 'perl',
    dist_author         => 'Gregory Todd Williams <gwilliams@cpan.org>',
    dist_version_from   => 'lib/RDF/Store/DBI.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'RDF-Store-DBI-*' ],
);

$builder->create_build_script();
