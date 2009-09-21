use strict;
use warnings;
no warnings 'redefine';

# use ExtUtils::MakeMaker;
use inc::Module::Install;

license				'perl';

recommends			'Apache::DBI'				=> 0;

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;
build_requires		'FindBin'					=> 0;

WriteMakefile(
	NAME				=> 'RDF::Endpoint',
	ABSTRACT			=> 'SPARQL Endpoint implementation for Apache and CGI',
	VERSION_FROM		=> 'lib/RDF/Endpoint.pm',
	AUTHOR				=> 'Gregory Todd Williams <gwilliams@cpan.org>',
	PREREQ_PM			=> {
					'Digest::SHA1'							=> 0,
					'File::Slurp'							=> 0,
					'HTTP::Server::Simple::CGI'				=> 0,
					'List::Util'							=> 0,
					'LWP::UserAgent'						=> 0,
					'LWPx::ParanoidAgent'					=> 0,
					'Module::Install::Base'					=> 0,
					'RDF::Query'							=> 2,
					'RDF::Trine'							=> 0,
					'Scalar::Util'							=> 0,
					'Template'								=> 0,
					'URI::Escape'							=> 0,
				},
);
