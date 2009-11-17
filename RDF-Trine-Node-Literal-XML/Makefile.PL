use strict;
use warnings;

use inc::Module::Install;

license				'perl';

name                    'RDF-Trine-Node-Literal-XML';
author	                'Kjetil Kjernsmo <kjetilk@cpan.org>';
version_from        	'lib/RDF/Trine/Node/Literal/XML.pm';
abstract_from       	'lib/RDF/Trine/Node/Literal/XML.pm';


test_requires		'Test::More'				=> '0.61';
test_requires		'Test::Exception'			=> 0;

include                 'Test::Signature';



requires 		'RDF::Trine'				=> 0.111;
requires		'Scalar::Util'				=> 0;
requires		'XML::LibXML'				=> 0;
requires		'Error'					=> 0;

WriteAll;
