use strict;
use warnings;
no warnings 'redefine';

use inc::Module::Install;

license				'perl';

build_requires		'Test::More'				=> 0.61;
build_requires		'Test::Exception'			=> 0;

### Recommended to build the XS version of RDF::Base::Storage::DBI::_mysql_hash
recommends			'ExtUtils::CBuilder'		=> 0;
recommends			'ExtUtils::ParseXS'			=> 0;
#####################################################

recommends			'DBI'						=> 0;
recommends			'DBD::SQLite'				=> 0;
recommends			'RDF::Redland'				=> 1;
recommends			'Math::BigInt'				=> 1;

WriteMakefile(
    NAME                		=> 'RDF::Base',
	AUTHOR						=> 'Gregory Todd Williams <gwilliams@cpan.org>',
    VERSION_FROM        		=> 'lib/RDF/Base.pm',
    ABSTRACT_FROM       		=> 'lib/RDF/Base.pm',
    PREREQ_PM => {
    	'URI'					=> 0,
        'version'				=> 0,
        'Module::Pluggable'		=> 2.95,
        'Scalar::Util'			=> 0,
        'Params::Coerce'		=> 0,
        'LWP::Simple'			=> 0,
        'RDF::Query::Node'		=> 0,
        'RDF::SPARQLResults'	=> 0,
        'Error'					=> 0,
        'Encode'				=> 0,
        'Digest::MD5'			=> 0,
        'Data::Dumper'			=> 0,
        'Moose'					=> 0,
        'XML::Namespace'		=> 0,
    },
);
