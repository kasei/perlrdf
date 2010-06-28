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

<http://kasei.us/code/rdf-query/#project> a doap:Project ;
	doap:release [ a doap:Version ; doap:homepage <http://kasei.us/code/rdf-query/> ] .

_:greg a foaf:Person ;
	foaf:name "Gregory Todd Williams" ;
	foaf:mbox <mailto:gwilliams@cpan.org> ;
	foaf:mbox_sha1sum "f80a0f19d2a0897b89f48647b2fb5ca1f0bc1cb8" ;
	foaf:homepage <http://kasei.us/> .

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
	earl:assertedBy _:greg ;
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
	my $bridge	= $earl->{bridge};
	if (blessed($test) and $test->isa('RDF::Trine::Node')) {
		$test	= $test->uri_value;
	}
	
	print {$earl->{fh}} <<"END";
[] a earl:Assertion;
	earl:assertedBy _:greg ;
	earl:result [
		a earl:TestResult ;
		earl:outcome earl:fail
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

