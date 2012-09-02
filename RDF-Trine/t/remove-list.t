use RDF::Trine;
use RDF::Trine::Namespace qw[RDF];
use Test::More tests => 8;
use Test::Exception;

ok(RDF::Trine::Model->can('remove_list'), "There's a remove_list method.");

my $EX = RDF::Trine::Namespace->new('http://example.com/');

my $model  = &test_model;
{
	my ($head) = $model->objects(undef, $EX->list1);
	my $rv     = $model->remove_list($head, orphan_check=>1);
	ok($rv->equal($head), "Refused to remove non-orphan list when checking for orphans");
	$rv = $model->remove_list($head, orphan_check=>0);
	is($rv, undef, "Removed non-orphan list when not checking for orphans");
}
{
	my ($head) = $model->objects(undef, $EX->list2);
	throws_ok { $model->remove_list($head) } 'RDF::Trine::Error', 'Malformed lists throw';
}
{
	my ($head) = $model->objects(undef, $EX->list3);
	
	$model->remove_statements(undef, $EX->list3, $head); # still not an orphan!
	my $rv = $model->remove_list($head, orphan_check=>1);
	ok($rv, "Refused to remove different non-orphan list when checking for orphans");
	is($model->count_statements($rv, $EX->first, RDF::Trine::Node::Literal->new('b')), 1, "Correct node returned by orphan check.");
	my $rv2 = $model->remove_list($rv, orphan_check=>0);
	is($rv2, undef, "Removed different non-orphan list when not checking for orphans");
	is($model->count_statements($rv, $EX->first, RDF::Trine::Node::Literal->new('b')), 1, "Unrelated triples kept when deleting a list.");
}

sub test_model
{
	my $model  = RDF::Trine::Model->temporary_model;
	my $parser = RDF::Trine::Parser->new('Turtle');
	$parser->parse_into_model('http://example.net/', <<'TURTLE', $model);
	
@prefix ex:  <http://example.com/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .

[]
	ex:list1 ("a" "b" "c" "d") ;
	ex:list2 [ a rdf:List ; rdf:first "a" , "b" ; rdf:rest ("c" "d") ] ;
	ex:list3 [
		a rdf:List ;
		rdf:first "a" ;
		rdf:rest [
			a rdf:List ;
			rdf:first "b" ;
			ex:first "b" ;
			rdf:rest ("c" "d")
			]
		].
	
TURTLE
	return $model;
}

