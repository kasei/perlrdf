use strict;
use warnings;
no warnings 'redefine';

sub init_earl {
	my $bridge	= shift;
	my $out		= '';
	open( my $fh, '>', \$out );
	my $earl	= {out => \$out, fh => $fh, bridge => $bridge};
	
	print {$fh} <<'END';
@prefix doap: <http://usefulinc.com/ns/doap#>.
@prefix earl: <http://www.w3.org/ns/earl#>.
@prefix foaf: <http://xmlns.com/foaf/0.1/>.
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>.
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>.
@prefix xml: <http://www.w3.org/XML/1998/namespace>.
@prefix rdfquery: <http://kasei.us/code/rdf-query/#>.
@prefix dct: <http://purl.org/dc/terms/>.

rdfquery:project
	a doap:Project ;
	doap:name "RDF::Query" ;
	doap:homepage <http://metacpan.org/dist/RDF-Query/> .

<http://kasei.us/about/foaf.xrdf#greg> a foaf:Person ;
	foaf:name "Gregory Todd Williams" ;
	foaf:mbox <mailto:gwilliams@cpan.org> ;
	foaf:mbox_sha1sum "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" ;
	foaf:homepage <http://kasei.us/> .

rdfquery:dawg-harness
	a earl:Software ;
	dct:title "RDF::Query DAWG test harness" ;
	foaf:maker <http://kasei.us/about/foaf.xrdf#greg> .


END
	return $earl;
}

sub earl_pass_test {
	my $earl	= shift;
	my $test	= shift;
	my $bridge	= $earl->{bridge};
	if (blessed($test) and $test->isa('RDF::Trine::Node')) {
		$test	= $test->uri_value;
	}
	
	print {$earl->{fh}} <<"END";
[] a earl:Assertion;
	earl:assertedBy rdfquery:dawg-harness ;
	earl:result [
		a earl:TestResult ;
		earl:outcome earl:pass
	] ;
	earl:subject rdfquery:project ;
	earl:test <$test> .
END
}

sub earl_fail_test {
	my $earl	= shift;
	my $test	= shift;
	my $msg		= shift;
	no warnings 'uninitialized';
	$msg		=~ s/\n/\\n/g;
	$msg		=~ s/\t/\\t/g;
	$msg		=~ s/\r/\\r/g;
	$msg		=~ s/"/\\"/g;
	
	my $bridge	= $earl->{bridge};
	if (blessed($test) and $test->isa('RDF::Trine::Node::Resource')) {
		$test	= $test->uri_value;
	} elsif (blessed($test) and $test->isa('RDF::Trine::Node')) {
		$test	= $test->as_string;
	}
	
	print {$earl->{fh}} <<"END";
[] a earl:Assertion;
	earl:assertedBy rdfquery:dawg-harness ;
	earl:result [
		a earl:TestResult ;
		earl:outcome earl:fail ;
END
	print {$earl->{fh}} qq[\t\trdfs:comment "$msg" ;\n] if (defined $msg);
	print {$earl->{fh}} <<"END";
	] ;
	earl:subject rdfquery:project ;
	earl:test <$test> .
END
}

sub earl_output {
	my $earl	= shift;
	close($earl->{fh});
	return ${ $earl->{out} };
}

1;

__END__

