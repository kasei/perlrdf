use strict;
use warnings;

use inc::Module::Install;

my $dist = 'RDF-Endpoint-Plack';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                'RDF-Endpoint-Plack';
all_from            'lib/RDF/Endpoint/Plack.pm';
author              'Gregory Todd Williams <gwilliams@cpan.org>';
license             'perl';

test_requires       'Test::More' => '0.61';

requires            'Carp'            => 0;
requires            'File::ShareDir'  => 0;
requires            'RDF::Trine'      => 0.123;
requires            'RDF::Query'      => 2.202;
requires            'Plack::Request'  => 0;
requires            'Plack::Response' => 0;
requires            'Data::Dumper'    => 0;
requires            'Config::JFDI'    => 0;
requires            'HTTP::Negotiate' => 0;

auto_set_bugtracker;

resources(
	'homepage'   => "http://search.cpan.org/dist/$dist/",
	'repository' => "http://github.com/kasei/perlrdf/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
);

write_doap_changes;
write_doap_changes_xml;

install_share;
install_script glob('script/*');

sign;

WriteAll;
