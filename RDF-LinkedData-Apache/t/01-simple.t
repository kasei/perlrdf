use Test::More tests => 39;
use Test::Exception;
use Test::MockObject;

use strict;
use warnings;

use File::Temp;
use Data::Dumper;

BEGIN {
	Test::MockObject->fake_module( 'Apache2::Request' );
	Test::MockObject->fake_module( 'Apache2::RequestUtil' );
	Test::MockObject->fake_module( 'Apache2::RequestRec' );
	Test::MockObject->fake_module( 'Apache2::Const', map { my $name = $_; $name => sub {$name} } qw(OK NOT_FOUND DECLINED HTTP_SEE_OTHER) );
	Test::MockObject->fake_module( 'DBI', 'connect' => sub {
		my $dbh	= Test::MockObject->new();
		return $dbh;
	} );
}

use RDF::Trine qw(iri literal);
use RDF::Trine::Namespace qw(rdf rdfs);
use RDF::LinkedData::Apache;

throws_ok { RDF::LinkedData::Apache->new('') } 'Error', 'constructor throws without a request object';
throws_ok {
	new_handler( dir_config => [] )
} 'Error', 'constructor throws without necessary dir_configs';

{
	print "# handler() call\n";
	my (%headers, %errors);
	my $headers	= Test::MockObject->new();
	my $errors	= Test::MockObject->new();
	$errors->mock( 'add' => sub { shift; $errors{ $_[0] } = $_[1]; } );
	$headers->mock( 'add' => sub { shift; $headers{ $_[0] } = $_[1]; } );
	
	my $r = Test::MockObject->new();
	$r->set_series( 'dir_config', 'http://base', 'Memory' );
	$r->set_always( 'header_out', sub { shift; $headers{ $_[0] } = $_[1]; } );
	$r->set_always( 'err_headers_out', $errors );
	
	my $ctype;
	my $content	= '';
	$r->mock( 'content_type', sub { shift; if (@_) { $ctype = shift; } return $ctype; } );
	$r->mock( 'print', sub { shift; $content .= shift } );
	$r->mock( '_mock_content', sub { return $content; } );
	$r->set_always( 'filename', '' );
	$r->set_always( 'uri', '/foo' );
	
	my $ret	= RDF::LinkedData::Apache->handler( $r );
	is( $ret, 'HTTP_SEE_OTHER', 'expected return value from handler()' );
}

{
	print "# handler() call for on-disk file\n";
	my $r = Test::MockObject->new();
	my $tmp	= File::Temp->new( UNLINK => 0, SUFFIX => '.dat' );
	my $filename	= "$tmp";
	$r->set_always( 'uri', '/foo' );
	$r->set_always( 'filename', $filename );
	
	my $ret	= RDF::LinkedData::Apache->handler( $r );
	is( $ret, 'DECLINED', 'expected DECLINE for request of existing file' );
}

{
	print "# page redirection\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'DBI;model;dsn;user;password']);
	$r->set_always( 'uri', '/foo' );
	isa_ok( $handler, 'RDF::LinkedData::Apache' );
	is( $handler->request, $r, 'request object' );
	isa_ok( $handler->model, 'RDF::Trine::Model', 'model object' );
	isa_ok( $handler->model->_store, 'RDF::Trine::Store::DBI', 'DBI-based store backing the model' );
	is( $handler->base, 'http://base', 'base' );
	
	$handler->run;
	is_deeply( $errors, { Vary => 'Accept', Location => 'http://base/foo/page' }, 'expected page error headers' );
}

{
	print "# data redirection\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo' );
	local($ENV{HTTP_ACCEPT})	= 'application/rdf+xml';
	$handler->run;
	is_deeply( $errors, { Vary => 'Accept', Location => 'http://base/foo/data' }, 'expected data error headers' );
}

{
	print "# bad data request\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/data' );
	local($ENV{HTTP_ACCEPT})	= 'application/rdf+xml';
	
	my $ret	= $handler->run;
	is( $ret, 'NOT_FOUND', 'request for non-existing data' );
	is_deeply( $headers, {}, 'expected data headers' );
	is_deeply( $errors, {}, 'expected data error headers' );
}

{
	print "# data request for rdf/xml\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/data' );
	local($ENV{HTTP_ACCEPT})	= 'application/rdf+xml';
	my $model	= $handler->model;
	my $st		= RDF::Trine::Statement->new( iri('http://base/foo'), $rdfs->label, literal('label') );
	$model->add_statement( $st );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'application/rdf+xml', 'expected content type' );
	like( $r->_mock_content, qr[:label>label</]ms, 'expected content' );
}

{
	print "# data request for ntriples\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/data' );
	local($ENV{HTTP_ACCEPT})	= 'text/n3';
	my $model	= $handler->model;
	my $st		= RDF::Trine::Statement->new( iri('http://base/foo'), $rdfs->label, literal('label') );
	$model->add_statement( $st );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/plain', 'expected content type' );
	like( $r->_mock_content, qr[<http://base/foo> <http://www.w3.org/2000/01/rdf-schema#label> "label"]ms, 'expected content' );
}

{
	print "# page request\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/page' );
	local($ENV{HTTP_ACCEPT})	= 'text/html';
	my $model	= $handler->model;
	my $st		= RDF::Trine::Statement->new( iri('http://base/foo'), $rdfs->label, literal('label') );
	$model->add_statement( $st );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/html', 'expected content type' );
	like( $r->_mock_content, qr[<span xmlns:ns="http://www.w3.org/2000/01/rdf-schema#" property="ns:label">label</span>]ms, 'expected content' );
}

{
	print "# page request with labeled statement object\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/page' );
	local($ENV{HTTP_ACCEPT})	= 'text/html';
	my $model	= $handler->model;
	$model->add_statement( RDF::Trine::Statement->new( iri('http://base/foo'), $rdfs->label, literal('foo') ) );
	$model->add_statement( RDF::Trine::Statement->new( iri('foo'), $rdfs->label, literal('Foo') ) );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/html', 'expected content type' );
	like( $r->_mock_content, qr[<span xmlns:ns="http://www.w3.org/2000/01/rdf-schema#" property="ns:label">foo</span>]ms, 'expected content' );
}

{
	print "# page request with unlabeled statement object\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/page' );
	local($ENV{HTTP_ACCEPT})	= 'text/html';
	my $model	= $handler->model;
	$model->add_statement( RDF::Trine::Statement->new( iri('http://base/foo'), $rdfs->label, iri('http://foo/') ) );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/html', 'expected content type' );
	like( $r->_mock_content, qr[<h1>http://base/foo</h1>]ms, 'expected node title' );
	like( $r->_mock_content, qr[<a xmlns:ns="http://www.w3.org/2000/01/rdf-schema#" rel="ns:label" href="http://foo/">http://foo/</a>]ms, 'expected content' );
}

{
	print "# page request with rdfs container proeprty\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/page' );
	local($ENV{HTTP_ACCEPT})	= 'text/html';
	my $model	= $handler->model;
	$model->add_statement( RDF::Trine::Statement->new( iri('http://base/foo'), $rdf->_2, iri('http://foo/') ) );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/html', 'expected content type' );
	like( $r->_mock_content, qr[<td>#2</td><td><a xmlns:ns="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rel="ns:_2" href="http://foo/">http://foo/</a></td>]ms, 'expected content' );
}

{
	print "# page request with non-qnameable property\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/page' );
	local($ENV{HTTP_ACCEPT})	= 'text/html';
	my $model	= $handler->model;
	$model->add_statement( RDF::Trine::Statement->new( iri('http://base/foo'), iri('http://example/123'), iri('http://foo/') ) );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/html', 'expected content type' );
	like( $r->_mock_content, qr[<td>http://example/123</td><td><a href="http://foo/">http://foo/</a></td>]ms, 'expected content' );
}

{
	print "# page request with labeled predicate\n";
	my ($handler, $r, $headers, $errors)	= new_handler( dir_config => ['http://base', 'Memory']);
	$r->set_always( 'uri', '/foo/page' );
	local($ENV{HTTP_ACCEPT})	= 'text/html';
	my $model	= $handler->model;
	$model->add_statement( RDF::Trine::Statement->new( iri('http://base/foo'), iri('http://example/123'), iri('http://foo/') ) );
	$model->add_statement( RDF::Trine::Statement->new( iri('http://example/123'), $rdfs->label, literal('predicate') ) );
	
	my $ret	= $handler->run;
	is( $ret, 'OK', 'request for existing data' );
	is( $r->content_type, 'text/html', 'expected content type' );
	like( $r->_mock_content, qr[<td>predicate</td><td><a href="http://foo/">http://foo/</a></td>]ms, 'expected content' );
}

################################################################################

sub new_handler {
	my %args	= @_;
	my (%headers, %errors);
	my $headers	= Test::MockObject->new();
	my $errors	= Test::MockObject->new();
	$errors->mock( 'add' => sub { shift; $errors{ $_[0] } = $_[1]; } );
	$headers->mock( 'add' => sub { shift; $headers{ $_[0] } = $_[1]; } );
	
	my $r = Test::MockObject->new();
	$r->set_series( 'dir_config', @{ $args{ 'dir_config' } } );
	$r->set_always( 'header_out', sub { shift; $headers{ $_[0] } = $_[1]; } );
	$r->set_always( 'err_headers_out', $errors );
	
	my $ctype;
	my $content	= '';
	$r->mock( 'content_type', sub { shift; if (@_) { $ctype = shift; } return $ctype; } );
	$r->mock( 'print', sub { shift; $content .= shift } );
	$r->mock( '_mock_content', sub { return $content; } );
	
	my $handler	= RDF::LinkedData::Apache->new( $r );
	return ($handler, $r, \%headers, \%errors);
}
