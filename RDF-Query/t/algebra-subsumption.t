#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use utf8;

use Test::More tests => 9;
use Test::Exception;
use Scalar::Util qw(reftype blessed);

use RDF::Query;
use RDF::Query::Node;
use RDF::Query::Algebra;

my $la		= RDF::Query::Node::Literal->new( 'a' );
my $lb		= RDF::Query::Node::Literal->new( 'b' );
my $ra		= RDF::Query::Node::Resource->new( 'http://example.org/a' );
my $rb		= RDF::Query::Node::Resource->new( 'http://example.org/b' );
my $va		= RDF::Query::Node::Variable->new( 'a' );
my $vb		= RDF::Query::Node::Variable->new( 'b' );

{
	# triple-triple subsumption testing
	my $triple		= RDF::Query::Algebra::Triple->new( $ra, $rb, $la );
	my $patterna	= RDF::Query::Algebra::Triple->new( $ra, $rb, $va );
	my $patternb	= RDF::Query::Algebra::Triple->new( $ra, $rb, $vb );
	my $patternc	= RDF::Query::Algebra::Triple->new( $va, $va, $vb );
	ok( $patterna->subsumes( $triple ), 'triple pattern subsumes triple (a)' );
	ok( $patternb->subsumes( $triple ), 'triple pattern subsumes triple (b)' );
	TODO: {
		local($TODO)	= "subsumption testing needs to respect repeated variables";
		ok( not($patternc->subsumes( $triple )), "pattern with repeated variables doesn't subsume triple (c)" );
	}
	ok( not($triple->subsumes( $patterna )), "triple doesn't subsume pattern" );
}

{
	# bgp-bgp subsumption testing
	my $triplea		= RDF::Query::Algebra::Triple->new( $ra, $ra, $la );
	my $tripleb		= RDF::Query::Algebra::Triple->new( $ra, $rb, $lb );
	my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( $triplea, $tripleb );
	
	my $ptriplea	= RDF::Query::Algebra::Triple->new( $ra, $ra, $va );
	my $ptripleb	= RDF::Query::Algebra::Triple->new( $ra, $rb, $vb );
	my $patterna	= RDF::Query::Algebra::BasicGraphPattern->new( $ptriplea, $ptripleb );
	ok( $patterna->subsumes( $bgp ), 'bgp pattern subsumes bgp (a)' );

	TODO: {
		local($TODO)	= "subsumption testing needs to respect repeated variables";
		my $ptriplec	= RDF::Query::Algebra::Triple->new( $ra, $ra, $va );
		my $ptripled	= RDF::Query::Algebra::Triple->new( $ra, $rb, $va );
		my $patternb	= RDF::Query::Algebra::BasicGraphPattern->new( $ptriplec, $ptripled );
		ok( not($patternb->subsumes( $bgp )), "bgp pattern with repeated variables doesn't subsume bgp (b)" );
	}
}

{
	# bgp-triple subsumption testing
	my $ptriplea	= RDF::Query::Algebra::Triple->new( $ra, $ra, $va );
	my $ptripleb	= RDF::Query::Algebra::Triple->new( $ra, $rb, $vb );
	my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( $ptriplea, $ptripleb );
	
	my $triplea		= RDF::Query::Algebra::Triple->new( $ra, $ra, $la );
	my $tripleb		= RDF::Query::Algebra::Triple->new( $ra, $rb, $lb );
	my $triplec		= RDF::Query::Algebra::Triple->new( $rb, $ra, $la );
	ok( $bgp->subsumes( $triplea ), 'bgp pattern subsumes triple (a)' );
	ok( $bgp->subsumes( $tripleb ), 'bgp pattern subsumes triple (b)' );
	ok( not($bgp->subsumes( $triplec )), "bgp pattern doesn't subsumes triple (c)" );
}
