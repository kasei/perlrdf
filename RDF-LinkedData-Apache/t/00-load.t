use Test::More tests => 1;
use Test::MockObject;

Test::MockObject->fake_module( 'Apache2::Request' );
Test::MockObject->fake_module( 'Apache2::RequestUtil' );
Test::MockObject->fake_module( 'Apache2::RequestRec' );
Test::MockObject->fake_module( 'Apache2::Const', map { my $name = $_; $name => sub {$name} } qw(OK NOT_FOUND DECLINED HTTP_SEE_OTHER) );
Test::MockObject->fake_module( 'DBI' );

use_ok( 'RDF::LinkedData::Apache' );


