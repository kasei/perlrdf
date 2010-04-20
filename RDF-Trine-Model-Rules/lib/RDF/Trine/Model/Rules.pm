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






RDFS Rules:

### inference rules for RDF(S)

{?S ?P ?O} => {?P a rdf:Property}.

{?P @has rdfs:domain ?C. ?S ?P ?O} => {?S a ?C}.

{?P @has rdfs:range ?C. ?S ?P ?O} => {?O a ?C}.

{?S ?P ?O} => {?S a rdfs:Resource}.
{?S ?P ?O} => {?O a rdfs:Resource}.

{?Q rdfs:subPropertyOf ?R. ?P rdfs:subPropertyOf ?Q} => {?P rdfs:subPropertyOf ?R}.

{?P @has rdfs:subPropertyOf ?R. ?S ?P ?O} => {?S ?R ?O}.

{?C a rdfs:Class} => {?C rdfs:subClassOf rdfs:Resource}.

{?A rdfs:subClassOf ?B. ?S a ?A} => {?S a ?B}.

{?B rdfs:subClassOf ?C. ?A rdfs:subClassOf ?B} => {?A rdfs:subClassOf ?C}.

{?X a rdfs:ContainerMembershipProperty} => {?X rdfs:subPropertyOf rdfs:member}.

{?X a rdfs:Datatype} => {?X rdfs:subClassOf rdfs:Literal}.

# 
# # RDFS RULES
# my @rules					= qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp Class_Resource subClass subClass_Trans member Datatype);
# my %rules					= (
# 								Property			=> ['[] ?p []'												=> '?p a rdf:Property'],
# 								domain				=> ['?p rdfs:domain ?c . ?s ?p []'							=> '?s a ?c'],
# 								range				=> ['?p rdfs:range ?c . [] ?p ?o'							=> '?o a ?c'],
# 								Subj_Resource		=> ['?s [] []'												=> '?s a rdfs:Resource'],
# 								Obj_Resource		=> ['[] [] ?o . FILTER(!ISLITERAL(?o))'						=> '?o a rdfs:Resource'],
# 								subProp_Trans		=> ['?q rdfs:subPropertyOf ?r. ?p rdfs:subPropertyOf ?q'	=> '?p rdfs:subPropertyOf ?r'],
# 								subProp				=> ['?p rdfs:subPropertyOf ?r . ?s ?p ?o'					=> '?s ?r ?o'],
# 								Class_Resource		=> ['?c a rdfs:Class'										=> '?c rdfs:subClassOf rdfs:Resource'],
# 								subClass			=> ['?a rdfs:subClassOf ?b . ?s a ?a'						=> '?s a ?b'],
# 								subClass_Trans		=> ['?b rdfs:subClassOf ?c. ?a rdfs:subClassOf ?b'			=> '?a rdfs:subClassOf ?c'],
# 								member				=> ['?x a rdfs:ContainerMembershipProperty'					=> '?x rdfs:subPropertyOf rdfs:member'],
# 								Datatype			=> ['?x a rdfs:Datatype'									=> '?x rdfs:subClassOf rdfs:Literal'],
# 							);
# 
# # After a rules adds triples to the store, which other rules might now need to fire based on the new triples?
# my %chaining_rules			= (
# 								Property		=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass )],
# 								domain			=> [qw(Property domain range Subj_Resource Obj_Resource subProp Class_Resource subClass)],
# 								range			=> [qw(Property domain range Subj_Resource Obj_Resource subProp Class_Resource subClass)],
# 								Subj_Resource	=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass)],
# 								Obj_Resource	=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass)],
# 								subProp_Trans	=> [qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp)],
# 								subProp			=> [qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp Class_Resource subClass subClass_Trans member Datatype)],
# 								Class_Resource	=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass subClass_Trans)],
# 								subClass		=> [qw(Property domain range Subj_Resource Obj_Resource subProp Class_Resource subClass)],
# 								subClass_Trans	=> [qw(Property domain range Subj_Resource Obj_Resource subClass subClass_Trans)],
# 								member			=> [qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp)],
# 								Datatype		=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass subClass_Trans)],
# 							);

