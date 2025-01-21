use Test::More;
use Test::Exception;

use strict;
use warnings;
no warnings 'redefine';
use Scalar::Util qw(blessed reftype);
use utf8;

use RDF::Trine qw(statement iri literal blank);
use RDF::Trine::Namespace qw(rdf foaf);

my $ex		= RDF::Trine::Namespace->new('http://example.com/');
my $ns		= RDF::Trine::Namespace->new('http://example.com/ns#');
my $lang	= RDF::Trine::Namespace->new('http://purl.org/net/inkel/rdf/schemas/lang/1.1#');
my $nil		= RDF::Trine::Node::Nil->new();

################################################################################


my @tests	= (
	{
		quads	=> [
			statement($ex->s, $ex->p, $ex->o, $nil),
		],
		trig	=> qq[{\n\t<http://example.com/s> <http://example.com/p> <http://example.com/o> .\n}\n],
		test	=> 'single quad',
	},
	{
		sargs	=> [ namespaces =>  { foaf => 'http://xmlns.com/foaf/0.1/' } ],
		quads	=> [
			statement($ex->alice, $foaf->name, literal('Alice'), $nil),
		],
		trig	=> qq[\@prefix foaf: <http://xmlns.com/foaf/0.1/> .\n\n{\n\t<http://example.com/alice> foaf:name "Alice" .\n}\n],
		test	=> 'single quad with prefix name',
	},
	{
		quads	=> [
			statement($ex->s, $ex->p, $ex->o, $nil),
			statement($ex->s, $ex->p, literal('o'), $nil),
		],
		trig	=> qq[{\n\t<http://example.com/s> <http://example.com/p> <http://example.com/o> .\n\t<http://example.com/s> <http://example.com/p> "o" .\n}\n],
		test	=> 'two quads, shared s-p',
	},
	{
		quads	=> [
			statement($ex->s, $ex->p, $ex->o, $nil),
			statement($ex->s, $ex->p, literal('o'), $ex->g),
		],
		trig	=> qq[{\n\t<http://example.com/s> <http://example.com/p> <http://example.com/o> .\n}\n\n<http://example.com/g> {\n\t<http://example.com/s> <http://example.com/p> "o" .\n}\n],
		test	=> 'two quads, two graphs',
	},
	{
		sargs	=> [ namespaces =>  { ex => 'http://example.com/' } ],
		quads	=> [
			statement($ex->s, $ex->p, literal('o'), $ex->g),
		],
		trig	=> qq[\@prefix ex: <http://example.com/> .\n\nex:g {\n\tex:s ex:p "o" .\n}\n],
		test	=> 'one quad, with prefix name graph',
	},
);

foreach my $d (@tests) {
	my $quads	= $d->{quads};
	my $iter	= RDF::Trine::Iterator->new($quads);
	my @args	= exists($d->{sargs}) ? @{ $d->{sargs} } : ();
	my $s		= RDF::Trine::Serializer::TriG->new( @args );
	my $trig	= $s->serialize_iterator_to_string($iter);
	my $test	= $d->{test};
	my $expect	= $d->{trig};
	TODO: {
		my $re	= (blessed($expect) and $expect->isa('Regexp'));
		if ($test =~ /TODO/) {
			local $TODO	= "Not implemented yet";
			if ($re) {
				like($trig, $expect, $test);
			} else {
				is($trig, $expect, $test);
			}
		} else {
			if ($re) {
				like($trig, $expect, $test);
			} else {
				is($trig, $expect, $test);
			}
		}
	}
}

done_testing();
