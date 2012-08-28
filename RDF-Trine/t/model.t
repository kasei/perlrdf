use Test::More;
use Test::Moose;
use Test::Exception;

use utf8;
use strict;
use warnings;
no warnings 'redefine';

use DBI;
use RDF::Trine qw(literal);
use RDF::Trine::Model;
use RDF::Trine::Pattern;
use RDF::Trine::Namespace;
use RDF::Trine::Store::DBI;
use RDF::Trine::Statement::Triple;
use File::Temp qw(tempfile);

my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $foaf	= RDF::Trine::Namespace->new('http://xmlns.com/foaf/0.1/');
my $xsd		= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');
my $kasei	= RDF::Trine::Namespace->new('http://kasei.us/');
my $b		= RDF::Trine::Node::Blank->new();
my $p		= RDF::Trine::Node::Resource->new('http://kasei.us/about/foaf.xrdf#greg');
my $intval	= RDF::Trine::Node::Literal->new('23',undef,$xsd->int);
my $langval	= RDF::Trine::Node::Literal->new('gwilliams','en');
my $st0		= RDF::Trine::Statement->new( $p, $rdf->type, $foaf->Person );
my $st1		= RDF::Trine::Statement->new( $p, $foaf->name, RDF::Trine::Node::Literal->new('Gregory Todd Williams') );
my $st2		= RDF::Trine::Statement->new( $b, $rdf->type, $foaf->Person );
my $st3		= RDF::Trine::Statement->new( $b, $foaf->name, RDF::Trine::Node::Literal->new('Eve') );
my $st4		= RDF::Trine::Statement->new( $p, $foaf->knows, $b );
my $st5		= RDF::Trine::Statement->new( $p, $foaf->nick, $langval );
my $st6		= RDF::Trine::Statement->new( $p, $foaf->age, $intval);

my ($stores, $remove)	= stores();

plan tests => 7 + 93 * scalar(@$stores);

print "### Testing auto-creation of store\n";
isa_ok( RDF::Trine::Model->new( 'Memory' ), 'RDF::Trine::Model' );

foreach my $store (@$stores) {
	print "### Testing store " . ref($store) . "\n";
	does_ok( $store, 'RDF::Trine::Store::API' );
	my $model	= RDF::Trine::Model->new( $store );
	isa_ok( $model, 'RDF::Trine::Model' );
	$model->add_statement( $_ ) for ($st0, $st1, $st2, $st3);
	
	{
		is( $model->count_statements(), 4, 'model size' );
		$model->add_statement( $_ ) for ($st0);
		is( $model->count_statements(), 4, 'model size after duplicate statements' );
		is( $model->count_statements( undef, $foaf->name, undef ), 2, 'count of foaf:name statements' );
	}
	
	{
		my $stream	= $model->get_statements( $p, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $st		= $stream->next;
		is $st->subject->value,   $st1->subject->value,   'foaf:name statement subject';
		is $st->predicate->value, $st1->predicate->value, 'foaf:name statement predicate';
		is $st->object->value,    $st1->object->value,    'foaf:name statement object';
		is( $stream->next, undef, 'end-of-stream' );
	}
	
	{
		throws_ok {
			my $iter	= $model->get_statements('<foo>');
		} 'RDF::Trine::Error::MethodInvocationError', 'get_statements called with non-object argument';
		
	}
	
	{
		throws_ok {
			$model->add_statement($p, $rdf->type, $foaf->Person);
		} 'RDF::Trine::Error::MethodInvocationError', 'add_statement called with 3 nodes, not a statement';
		throws_ok {
			$model->add_statement($p, $rdf->type, $foaf->Person, $p);
		} 'RDF::Trine::Error::MethodInvocationError', 'add_statement called with 4 nodes, not a statement';
		throws_ok {
			$model->add_statement('http://example.org/subject', 'http://example.org/predicate', 'String');
		} 'RDF::Trine::Error::MethodInvocationError', 'add_statement called with strings, not a statement';
	}


	{
		my $stream	= $model->get_statements( $b, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $st		= $stream->next;
		is $st->subject->value, $st3->subject->value, 'foaf:name statement (with bnode in triple) subject';
		is $st->predicate->value, $st3->predicate->value, 'foaf:name statement (with bnode in triple) predicate';
		is $st->object->value, $st3->object->value, 'foaf:name statement (with bnode in triple) object';
		is( $stream->next, undef, 'end-of-stream' );
	}
	
	{
		my $stream	= $model->get_statements( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Literal->new('Gregory Todd Williams') );
		my $st		= $stream->next;
		is $st->subject->value, $st1->subject->value, 'foaf:name statement (with literal in triple) subject';
		is $st->predicate->value, $st1->predicate->value, 'foaf:name statement (with literal in triple) predicate';
		is $st->object->value, $st1->object->value, 'foaf:name statement (with literal in triple) object';
		is $st->object->datatype, $st1->object->datatype, 'foaf:name statement (with literal in triple) object-datatype';
		is $st->object->language, $st1->object->language, 'foaf:name statement (with literal in triple) object-language';
		is( $stream->next, undef, 'end-of-stream' );
	}

	{
		my $stream	= $model->get_statements( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $count	= 0;
		while (my $st = $stream->next) {
			my $subj	= $st->subject;
			ok( $subj->DOES('RDF::Trine::Node::API') );
			$count++;
		}
		is( $count, 2, 'expected result count (2 people) 1' );
	}
	
	{
		my $p1		= RDF::Trine::Statement->new( RDF::Trine::Node::Variable->new('p'), $rdf->type, $foaf->Person );
		my $p2		= RDF::Trine::Statement->new( RDF::Trine::Node::Variable->new('p'), $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $pattern	= RDF::Trine::Pattern->new( $p1, $p2 );
		
		{
			my $stream	= $model->get_pattern( $pattern );
			my $count	= 0;
			while (my $b = $stream->next) {
				isa_ok( $b, 'HASH' );
				ok( $b->{p}->DOES('RDF::Trine::Node::API'), 'node person' );
				isa_ok( $b->{name}, 'RDF::Trine::Node::Literal', 'literal name' );
				like( $b->{name}->literal_value, qr/Eve|Gregory/, 'name pattern' );
				$count++;
			}
			is( $count, 2, 'expected result count (2 people) 2' );
		}
	
		{
			my $stream	= $model->get_pattern( $pattern, undef, orderby => [ 'name', 'ASC' ] );
			is_deeply( [ $stream->sorted_by ], ['name', 'ASC'], 'results sort order' );
			my $count	= 0;
			my @expect	= ('Eve', 'Gregory Todd Williams');
			while (my $b = $stream->next) {
				isa_ok( $b, 'HASH' );
				ok( $b->{p}->DOES('RDF::Trine::Node::API'), 'node person' );
				my $name	= shift(@expect);
				is( $b->{name}->literal_value, $name, 'name pattern' );
				$count++;
			}
			is( $count, 2, 'expected result count (2 people) 3' );
		}

		{
			my $stream	= $model->get_pattern( $pattern, undef, orderby => [ qw(name DESC p ASC) ] );
			is_deeply( [ $stream->sorted_by ], ['name', 'DESC', 'p', 'ASC'], 'results sort order' );
			my $count	= 0;
			my @expect	= ('Gregory Todd Williams', 'Eve');
			while (my $b = $stream->next) {
				isa_ok( $b, 'HASH' );
				ok( $b->{p}->DOES('RDF::Trine::Node::API'), 'node person' );
				my $name	= shift(@expect);
				is( $b->{name}->literal_value, $name, 'name pattern' );
				$count++;
			}
			is( $count, 2, 'expected result count (2 people) 4' );
		}

		{
			my $stream	= $model->get_pattern( $pattern, undef, orderby => [ 'date', 'ASC' ] );
			is_deeply( [ $stream->sorted_by ], [], 'results sort order for unknown binding' );
		}
		
		{
			throws_ok {
				my $stream	= $model->get_pattern( $pattern, undef, orderby => [ 'name' ] );
			} 'RDF::Trine::Error::MethodInvocationError', 'bad ordering request throws exception';
		}
	}
	
	{
		my $stream	= $model->get_pattern( $st0 );
		my $empty	= $stream->next;
		is_deeply( $empty, RDF::Trine::VariableBindings->new({}), 'empty binding on no-variable pattern' );
		is( $stream->next, undef, 'end-of-stream' );
	}
	
	{
		my $stream	= $model->as_stream();
		isa_ok( $stream, 'RDF::Trine::Iterator::Graph' );
		my $count	= 0;
		while (my $st = $stream->next) {
			my $p	= $st->predicate;
			like( $p->uri_value, qr<(#type|/name)$>, 'as_stream statement' );
			$count++;
		}
		is( $count, 4, 'expected model statement count (4)' );
	}
	
	{
		{
			my @subj	= $model->subjects( $rdf->type );
			my @preds	= $model->predicates( $p );
			my @objs	= $model->objects( $p );
			is( scalar(@subj), 2, "expected subject count on rdf:type" );
			is( scalar(@preds), 2, "expected predicate count on " . $p->uri_value );
			is( scalar(@objs), 2, "expected objects count on " . $p->uri_value );
		}
		{
			my @subjs	= $model->subjects( $foaf->name, literal('Eve') );
			my @preds	= $model->predicates( $p, $foaf->Person );
			my @objs	= $model->objects( $p, $rdf->type );
			is( scalar(@subjs), 1, "expected subject count on rdf:type" );
			ok( $subjs[0]->isa('RDF::Trine::Node::Blank'), 'expected subject' );
			is( scalar(@preds), 1, "expected predicate count on " . $p->uri_value );
			ok( $preds[0]->equal( $rdf->type ), 'expected predicate' );
			is( scalar(@objs), 1, "expected objects count on " . $p->uri_value );
			ok( $objs[0]->equal( $foaf->Person ), 'expected object' );
		}
		{
			my $subjs	= $model->subjects( $rdf->type );
			my $preds	= $model->predicates( $p );
			my $objs	= $model->objects( $p );
			isa_ok( $subjs, 'RDF::Trine::Iterator', 'expected iterator from subjects()' );
			isa_ok( $preds, 'RDF::Trine::Iterator', 'expected iterator from predicates()' );
			isa_ok( $objs, 'RDF::Trine::Iterator', 'expected iterator from objects()' );
		}
	}
	
	{
		my $st5		= RDF::Trine::Statement->new( $p, $foaf->name, RDF::Trine::Node::Literal->new('グレゴリ　ウィリアムス', 'jp') );
		$model->add_statement( $st5 );
		
		my $pattern	= RDF::Trine::Statement->new( $p, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $stream	= $model->get_pattern( $pattern );
		my $count	= 0;
		while (my $b = $stream->next) {
			isa_ok( $b, 'HASH' );
			isa_ok( $b->{name}, 'RDF::Trine::Node::Literal', 'literal name' );
			my $value	= $b->{name}->literal_value;
			like( $value, qr/Gregory|グレゴリ/, 'name pattern with language-tagged result' );
			$count++;
		}
		is( $count, 2, 'expected result count (2 names)' );
		is( $model->count_statements(), 5, 'model size' );
		$model->remove_statement( $st5 );
		is( $model->count_statements(), 4, 'model size after remove_statement' );
	}
	
	{
		my $st6		= RDF::Trine::Statement->new( $p, $foaf->name, RDF::Trine::Node::Literal->new('Gregory Todd Williams', undef, 'http://www.w3.org/2000/01/rdf-schema#Literal') );
		$model->add_statement( $st6 );
		
		my $pattern	= RDF::Trine::Statement->new( $p, $foaf->name, RDF::Trine::Node::Variable->new('name') );
		my $stream	= $model->get_pattern( $pattern );
		my $count	= 0;
		my $dt		= 0;
		while (my $b = $stream->next) {
			my $name	= $b->{name};
			isa_ok( $b, 'HASH' );
			isa_ok( $name, 'RDF::Trine::Node::Literal', 'literal name' );
			is( $name->literal_value, 'Gregory Todd Williams', 'name pattern with datatyped result' );
			if (my $type = $name->literal_datatype) {
				is( $type, 'http://www.w3.org/2000/01/rdf-schema#Literal', 'datatyped literal' );
				$dt++;
			}
			$count++;
		}
		is( $count, 2, 'expected result count (2 names)' );
		is( $dt, 1, 'expected result count (1 datatyped literal)' );
	}
	
	{
		$model->remove_statements( $p );
		is( $model->count_statements(), 2, 'model size after remove_statements' );
	}
	
	{
		throws_ok {
			my $pattern	= RDF::Trine::Pattern->new();
			my $stream	= $model->get_pattern( $pattern );
		} 'RDF::Trine::Error::CompilationError', 'empty GGP throws exception';
	}
}

foreach my $file (@$remove) {
	unlink( $file );
}

{ # test optional parameters of RDF::Trine::Model::objects
	my $model = RDF::Trine::Model->new;
	$model->add_statement( $_ ) for ($st0, $st1, $st3, $st4, $st5, $st6);
	my %types = (blank => 1, literal => 3, resource => 1);
	while (my ($type,$count) = each(%types)) {
		my @objs	= $model->objects( $p, undef, type => $type );
		is( scalar(@objs), $count, "expected objects count on type $type");
	}
	my @objs	= $model->objects( $p, undef, language => 'en' );
	ok( $objs[0]->equal( $langval ), 'expected integer value as object' );
	foreach my $dt ( $xsd->int, $xsd->int->uri_value ) { 
		@objs	= $model->objects( $p, undef, datatype => $dt );
		ok( $objs[0]->equal( $intval ), 'expected integer value as object' );
	}
}


sub stores {
	my @stores;
	my @removeme;
	push(@stores, RDF::Trine::Store::Memory->temporary_store());
	
	{
		my $store	= RDF::Trine::Store::DBI->new();
		$store->init();
		push(@stores, $store);
	}
	
	{
		my ($fh, $filename) = tempfile();
		undef $fh;
		my $dbh		= DBI->connect( "dbi:SQLite:dbname=${filename}", '', '' );
		my $store	= RDF::Trine::Store::DBI->new( 'model', $dbh );
		$store->init();
		push(@stores, $store);
		push(@removeme, $filename);
	}
	
	{
		my ($fh, $filename) = tempfile();
		undef $fh;
		my $dsn		= "dbi:SQLite:dbname=${filename}";
		my $store	= RDF::Trine::Store::DBI->new( 'model', $dsn, '', '' );
		$store->init();
		push(@stores, $store);
		push(@removeme, $filename);
	}
	return (\@stores, \@removeme);
}

sub debug {
	my $store	= shift;
	my $dbh		= $store->dbh;
	my $sth		= $dbh->prepare( "SELECT * FROM Statements15799945864759145248" );
	$sth->execute();
	while (my $row = $sth->fetchrow_hashref) {
		warn Dumper($row);
	}
}
