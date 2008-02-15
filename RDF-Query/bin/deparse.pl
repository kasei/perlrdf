#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';

use lib qw(../lib lib);

use Data::Dumper;
use RDF::Query::Parser::SPARQL;

binmode(STDIN, ':utf8');
my $input	= (scalar(@ARGV) == 0 or $ARGV[0] eq '-')
			? do { local($/) = undef; <> }
			: do { local($/) = undef; open(my $fh, '<', $ARGV[0]); binmode($fh, ':utf8'); <$fh> };
my $parser	= new RDF::Query::Parser::SPARQL ();
my $parsed	= $parser->parse( $input );
unless ($parsed) {
	warn $parser->error;
}

my $context	= {};
my $method	= $parsed->{method};
my @vars	= map { $_->as_sparql( $context ) } @{ $parsed->{ variables } };
my $vars	= join(' ', @vars);
my @triples	= @{ $parsed->{triples} };
my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( @triples );

{
	my $pvars	= join(' ', sort $ggp->referenced_variables);
	my $svars	= join(' ', sort map { $_->name } @{ $parsed->{ variables } });
	if ($pvars eq $svars) {
		$vars	= '*';
	}
}

my @ns		= map { "PREFIX $_: <$parsed->{namespaces}{$_}>" } (keys %{ $parsed->{namespaces} });
my $mod		= '';
if (my $ob = $parsed->{options}{orderby}) {
	$mod	= 'ORDER BY ' . join(' ', map {
				my ($dir,$v) = @$_;
				($dir eq 'ASC')
					? $v->as_sparql( $context )
					: "${dir}" . $v->as_sparql( $context );
			} @$ob) . "\n";
}


my $methoddata;
if ($method eq 'SELECT') {
	$methoddata	= sprintf("%s %s\nWHERE", $method, $vars);
} elsif ($method eq 'ASK') {
	$methoddata	= $method;
} elsif ($method eq 'CONSTRUCT') {
	my $ctriples	= $parsed->{construct_triples};
	my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @$ctriples );
	$methoddata		= sprintf("%s %s\nWHERE", $method, $ggp->as_sparql( $context ));
} elsif ($method eq 'DESCRIBE') {
	my $ctriples	= $parsed->{construct_triples};
	my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @$ctriples );
	$methoddata		= sprintf("%s %s\nWHERE", $method, $vars);
}




print sprintf(
	"%s\n%s %s\n%s",
	join("\n", @ns),
	$methoddata,
	$ggp->as_sparql( $context ),
	$mod,
);
