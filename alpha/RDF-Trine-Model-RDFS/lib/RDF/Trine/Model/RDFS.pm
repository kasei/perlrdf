# RDF::Trine::Model::RDFS
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model::RDFS - RDF Model supporting RDFS inferencing.

=head1 SYNOPSIS

 use RDF::Trine::Model::RDFS;
 my $model	= RDF::Trine::Model::RDFS->new( $store );
 $model->run_inference;
 # ... do stuff here
 $model->clear_inference;

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model::RDFS;

use strict;
use warnings;
use base qw(RDF::Trine::Model);

use RDF::Query 2.000;

our $RDFS_INFER_CONTEXT_URI	= 'http://kasei.us/code/rdf-trine/inference#rdfs';
use constant USE_CHAINING	=> 1;

# RDFS RULES
my @rules					= qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp Class_Resource subClass subClass_Trans member Datatype);
my %rules					= (
								Property			=> ['[] ?p []'												=> '?p a rdf:Property'],
								domain				=> ['?p rdfs:domain ?c . ?s ?p []'							=> '?s a ?c'],
								range				=> ['?p rdfs:range ?c . [] ?p ?o'							=> '?o a ?c'],
								Subj_Resource		=> ['?s [] []'												=> '?s a rdfs:Resource'],
								Obj_Resource		=> ['[] [] ?o . FILTER(!ISLITERAL(?o))'						=> '?o a rdfs:Resource'],
								subProp_Trans		=> ['?q rdfs:subPropertyOf ?r. ?p rdfs:subPropertyOf ?q'	=> '?p rdfs:subPropertyOf ?r'],
								subProp				=> ['?p rdfs:subPropertyOf ?r . ?s ?p ?o'					=> '?s ?r ?o'],
								Class_Resource		=> ['?c a rdfs:Class'										=> '?c rdfs:subClassOf rdfs:Resource'],
								subClass			=> ['?a rdfs:subClassOf ?b . ?s a ?a'						=> '?s a ?b'],
								subClass_Trans		=> ['?b rdfs:subClassOf ?c. ?a rdfs:subClassOf ?b'			=> '?a rdfs:subClassOf ?c'],
								member				=> ['?x a rdfs:ContainerMembershipProperty'					=> '?x rdfs:subPropertyOf rdfs:member'],
								Datatype			=> ['?x a rdfs:Datatype'									=> '?x rdfs:subClassOf rdfs:Literal'],
							);

# After a rules adds triples to the store, which other rules might now need to fire based on the new triples?
my %chaining_rules			= (
								Property		=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass )],
								domain			=> [qw(Property domain range Subj_Resource Obj_Resource subProp Class_Resource subClass)],
								range			=> [qw(Property domain range Subj_Resource Obj_Resource subProp Class_Resource subClass)],
								Subj_Resource	=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass)],
								Obj_Resource	=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass)],
								subProp_Trans	=> [qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp)],
								subProp			=> [qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp Class_Resource subClass subClass_Trans member Datatype)],
								Class_Resource	=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass subClass_Trans)],
								subClass		=> [qw(Property domain range Subj_Resource Obj_Resource subProp Class_Resource subClass)],
								subClass_Trans	=> [qw(Property domain range Subj_Resource Obj_Resource subClass subClass_Trans)],
								member			=> [qw(Property domain range Subj_Resource Obj_Resource subProp_Trans subProp)],
								Datatype		=> [qw(Property domain range Subj_Resource Obj_Resource subProp subClass subClass_Trans)],
							);

=item C<< run_inference >>

Perform the RDFS inferencing using forward chaining until the fixpoint is reached.

=cut

sub run_inference {
	my $self		= shift;
	my $context		= RDF::Trine::Node::Resource->new( $RDFS_INFER_CONTEXT_URI );
	
	my @rules_to_run	= @rules;
	my $round	= 1;
	while (1) {
		printf("=====================> [%d]\n", $round++);
		my %next_rules;
		my $size	= $self->count_statements;
		foreach my $rule_name (@rules_to_run) {
			printf("------> [$rule_name]\n");
			my $rsize	= $self->count_statements;
			my $rule	= $rules{ $rule_name };
			my ($body, $head)	= @$rule;
			my $sparql	= "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> CONSTRUCT { $head } WHERE { $body }";
			my $query	= RDF::Query->new( $sparql );
			my $iter	= $query->execute( $self );
			while (my $st = $iter->next) {
				if ($self->count_statements( $st->nodes ) == 0) {
					print $st->as_string . "\n";
					$self->add_statement( $st, $context );
				}
			}
			if (USE_CHAINING) {
				if ($rsize != $self->count_statements) {
					$next_rules{ $_ }++ foreach (@{ $chaining_rules{ $rule_name } });
				}
			}
		}
		if ($size == $self->count_statements) {
			last;
		}
		if (USE_CHAINING) {
			# only run the rules that might produce new triples based on the triples we just got through adding
			@rules_to_run	= keys %next_rules;
		} else {
			@rules_to_run	= @rules;
		}
	}
}

=item C<< clear_inference >>

Removes all the triples added to the store by the C<< run_inference >> method.
This method is based on the underlying store's support of contexts, so any
triples that were in the store before inferencing AND that would have been added
during inferencing should still exist after clearing the inference data (since
the inferred triple will have a different context).

=cut

sub clear_inference {
	my $self		= shift;
	my $context		= RDF::Trine::Node::Resource->new( $RDFS_INFER_CONTEXT_URI );
	
	$self->remove_statements( undef, undef, undef, $context );
}

1;

__END__

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

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
