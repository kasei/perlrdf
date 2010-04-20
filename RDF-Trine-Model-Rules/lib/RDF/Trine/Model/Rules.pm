=head1 NAME

RDF::Trine::Model::Rules - RDF Model supporting rule-based inferencing.

=head1 SYNOPSIS

 use RDF::Trine::Model::Rules;
 my $model	= RDF::Trine::Model::Rules->new( $store );
 my $rule	= RDF::Query->new('CONSTRUCT { ... } WHERE { ... }');
 $model->add_rule( $rule );
 $model->run_rules;

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model::Rules;

use strict;
use warnings;
use base qw(RDF::Trine::Model);

use RDF::Trine;
use RDF::Query 2.000;

our $debug	= 0;

=item C<< add_rule ( $rule ) >>

Given C<< $rule >>, a RDF::Query object representing a SPARQL CONSTRUCT query,
executes the query and inserts the resulting triples into this model.

=cut

sub add_rule {
	my $self	= shift;
	my $rule	= shift;
	push( @{ $self->{_rules} }, $rule );
	return;
}

=item C<< run_rules ( max_iterations => $MAX, named_graph => $name ) >>

Perform the rules-based inferencing using forward chaining. All of the key-value
arguments are optional.

If C<< max_iterations >> is specified, rule application is run at most
C<< $MAX >> times, otherwise until the fixpoint is reached.

If C<< named_graph >> is specified and a RDF::Trine::Node object, the triples
produced by the rule are added to the graph named C<< $name >>.

=cut

sub run_rules {
	my $self	= shift;
	my %args	= @_;
	my $max		= $args{ max_iterations } || -1;
	my $graph	= $args{ named_graph };
	my @rules	= @{ $self->{_rules} || [] };
	
	my $round	= 1;
	while (1) {
		printf("=====================> [%d]\n", $round++) if ($debug);
		my $size	= $self->count_statements;
		foreach my $i (0 .. $#rules) {
			my $rule	= $rules[ $i ];
			warn "rule $i\n" if ($debug);
			my $iter	= $rule->execute( $self );
			while (my $st = $iter->next) {
				if (defined($graph)) {
					my @nodes	= $st->nodes;
					$nodes[3]	= $graph;
					$st			= RDF::Trine::Statement::Quad->new( @nodes );
				}
				warn '==> adding statement: ' . $st->as_string if ($debug);
				$self->add_statement( $st );
			}
		}
		if ($size == $self->count_statements) {
			last;
		}
	}
	return;
}

=item C<< add_rdfs_rules >>

Adds a subset of the RDFS rules to the model ruleset. This set of rules does not
include some of the RDFS rules (including those that are not finite such as the
axiomatic container membership triples) or the literal generalization rules.

=cut

sub add_rdfs_rules {
	my $self	= shift;
	$self->add_rule( $_ ) for ($self->rdfs_rules);
}

=item C<< rdfs_rules >>

Returns a list of the rule objects used in the C<< add_rdfs_rules >> method.

=cut

sub rdfs_rules {
	my $self	= shift;
	my @rules;
	push(@rules, RDF::Query->new(<<"END"));	# axiomatic triples
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
CONSTRUCT {
	rdf:type rdf:type rdf:Property .
	rdf:subject rdf:type rdf:Property .
	rdf:predicate rdf:type rdf:Property .
	rdf:object rdf:type rdf:Property .
	rdf:first rdf:type rdf:Property .
	rdf:rest rdf:type rdf:Property .
	rdf:value rdf:type rdf:Property .
	rdf:nil rdf:type rdf:List .	
} WHERE {}
END
	push(@rules, RDF::Query->new('CONSTRUCT { ?p a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property> } WHERE { [] ?p [] }'));	# rdf1
	push(@rules, RDF::Query->new('CONSTRUCT { ?s a ?c } WHERE { ?p <http://www.w3.org/2000/01/rdf-schema#domain> ?c . ?s ?p [] }')); # rdfs2
	push(@rules, RDF::Query->new('CONSTRUCT { ?o a ?c } WHERE { ?p <http://www.w3.org/2000/01/rdf-schema#range> ?c . [] ?p ?o }'));	# rdfs3
	push(@rules, RDF::Query->new('CONSTRUCT { ?s a <http://www.w3.org/2000/01/rdf-schema#Resource> } WHERE { ?s [] [] }'));	# rdfs4a
	push(@rules, RDF::Query->new('CONSTRUCT { ?o a <http://www.w3.org/2000/01/rdf-schema#Resource> } WHERE { [] [] ?o }'));	# rdfs4b
	push(@rules, RDF::Query->new('CONSTRUCT { ?p <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?r } WHERE { ?q <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?r. ?p <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?q }'));	# rdfs5
	push(@rules, RDF::Query->new('CONSTRUCT { ?u <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?u> } WHERE { ?u a <http://www.w3.org/1999/02/22-rdf-syntax-ns#Property> }'));	# rdfs6
	push(@rules, RDF::Query->new('CONSTRUCT { ?s ?r ?o } WHERE { ?p <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> ?r . ?s ?p ?o }'));	# rdfs7
	push(@rules, RDF::Query->new('CONSTRUCT { ?c <http://www.w3.org/2000/01/rdf-schema#subClassOf> <http://www.w3.org/2000/01/rdf-schema#Resource> } WHERE { ?c a <http://www.w3.org/2000/01/rdf-schema#Class> }'));	# rdfs8
	push(@rules, RDF::Query->new('CONSTRUCT { ?s a ?b } WHERE { ?a <http://www.w3.org/2000/01/rdf-schema#subClassOf> ?b . ?s a ?a }'));	# rdfs9
	push(@rules, RDF::Query->new('CONSTRUCT { ?u <http://www.w3.org/2000/01/rdf-schema#subClassOf> ?u } WHERE { ?u a <http://www.w3.org/2000/01/rdf-schema#Class> }'));	# rdfs10
	push(@rules, RDF::Query->new('CONSTRUCT { ?a <http://www.w3.org/2000/01/rdf-schema#subClassOf> ?c } WHERE { ?b <http://www.w3.org/2000/01/rdf-schema#subClassOf> ?c. ?a <http://www.w3.org/2000/01/rdf-schema#subClassOf> ?b }'));	# rdfs11
	push(@rules, RDF::Query->new('CONSTRUCT { ?x <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> <http://www.w3.org/2000/01/rdf-schema#member> } WHERE { ?x a <http://www.w3.org/2000/01/rdf-schema#ContainerMembershipProperty> }'));	# rdfs12
	push(@rules, RDF::Query->new('CONSTRUCT { ?x <http://www.w3.org/2000/01/rdf-schema#subClassOf> <http://www.w3.org/2000/01/rdf-schema#Literal> } WHERE { ?x a <http://www.w3.org/2000/01/rdf-schema#Datatype> }'));	# rdfs13
	return @rules;
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to
C<< <gwilliams@cpan.org> >>.

=head1 SEE ALSO

L<http://www.perlrdf.org/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
