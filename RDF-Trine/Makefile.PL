use strict;
use warnings;

use inc::Module::Install;

name				'RDF-Trine';
all_from			'lib/RDF/Trine.pm';
author				'Gregory Todd Williams <gwilliams@cpan.org>';
license				'perl';

build_requires		'Test::More'				=> 0.88;
build_requires		'Test::Deep'				=> 0;
build_requires		'Test::Exception'			=> 0;
build_requires		'Test::JSON'				=> 0;

perl_version		'5.010';

requires			'IRI'						=> 0;
requires			'Moose'						=> 2;
requires			'MooseX::ArrayRef'			=> 0;
requires			'Module::Load::Conditional'	=> 0.38;
requires			'Data::UUID'				=> 0;
requires			'DBI'						=> 0;
requires			'DBIx::Connector'			=> 0;
requires			'DBD::SQLite'				=> 1.14;
requires			'Digest::MD5'				=> 0;
requires			'Digest::SHA'				=> 0;
requires			'Error'						=> 0;
requires			'HTTP::Negotiate'			=> 0;
requires			'JSON'						=> 2;
requires			'LWP::UserAgent'			=> 0;
requires			'List::Util'				=> 1.33;
requires			'Log::Log4perl'				=> 0;
requires			'Math::BigInt'				=> 0;
requires			'Algorithm::Combinatorics'	=> 0;
requires			'Scalar::Util'				=> 1.24;
requires			'Set::Scalar'				=> 0;
requires			'Storable'					=> 0;
requires			'Text::CSV_XS'				=> 0;
requires			'Text::Table'				=> 0;
requires			'URI'						=> 1.52;
requires			'XML::CommonNS'				=> 0.04;
requires			'XML::Namespace'			=> 0;
requires			'XML::SAX'					=> 0.96;
requires			'Time::HiRes'				=> 0;
requires			'Cache::LRU'				=> 0;
requires			'RDF::EARL'					=> 0;

recommends			'XML::LibXML'				=> 1.70;
recommends			'Term::ANSIColor'			=> 0;

resources(
	'homepage'		=> "http://search.cpan.org/dist/RDF-Trine/",
	'repository'	=> "http://github.com/kasei/perlrdf/",
	'bugtracker'	=> "https://github.com/kasei/perlrdf/issues",
	'IRC'			=> "irc://irc.perl.org/#perlrdf",
);

author_tests('xt');

install_script glob('bin/srx2csv');
install_script glob('bin/srx2table');

sign;

WriteAll;

print <<"END";

*******************************************************************************

The RDF::Trine SQLite backend in versions 1.013 and prior had a bug in
the encoding of RDF data, likely causing data loss.

RDF::Trine 1.014 and later have fixed this bug.

However, the RDF data encoded in SQLite with RDF::Trine versions 1.014 and
later will no longer be compatible with the shared schema used in other DBI
backends (such as PostgreSQL or MySQL). To exchange data between SQLite and
other databases, the data will require export to an RDF serialization and
re-import to the new database.

*******************************************************************************

END

