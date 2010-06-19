use strict;
use warnings;

use inc::Module::Install;

name                'RDF-Endpoint';
all_from            'lib/RDF/Endpoint.pm';
author              'Gregory Todd Williams <gwilliams@cpan.org>';
license             'perl';

test_requires       'Test::More' => '0.61';

requires            'Carp'                 => 0;
requires            'File::ShareDir'       => 0;
requires            'RDF::Trine'           => 0.123;
requires            'RDF::Query'           => 2.202;
requires            'RDF::RDFa::Generator' => 0;
requires            'Plack::Request'       => 0;
requires            'Plack::Response'      => 0;
requires            'Data::Dumper'         => 0;
requires            'Config::JFDI'         => 0;
requires            'HTTP::Negotiate'      => 0;

resources(
	'homepage'   => "http://search.cpan.org/dist/RDF-Endpoint/",
	'repository' => "http://github.com/kasei/perlrdf/",
);

write_doap_changes;
write_doap_changes_xml;

install_share;
install_script glob('script/*');

sign;

WriteAll;
