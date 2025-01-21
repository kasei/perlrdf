# RDF::Trine::Model
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model - Model class

=head1 VERSION

This document describes RDF::Trine::Model version 1.012

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model;

use strict;
use warnings;
no warnings 'redefine';

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

use Scalar::Util qw(blessed refaddr);
use Log::Log4perl;

use RDF::Trine::Error qw(:try);
use RDF::Trine qw(variable);
use RDF::Trine::Node;
use RDF::Trine::Pattern;
use RDF::Trine::Store;
use RDF::Trine::Model::Dataset;

=item C<< new ( $store ) >>

Returns a new model over the supplied L<rdf store|RDF::Trine::Store> or a new temporary model.
If you provide an unblessed value, it will be used to create a new rdf store.

=cut

sub new {
	my $class	= shift;
	if (@_) {
		my $store	= shift;
		$store		= RDF::Trine::Store->new( $store ) unless (blessed($store));
		my %args	= @_;
		my $self	= bless({
			store		=> $store,
			temporary	=> 0,
			added		=> 0,
			threshold	=> -1,
			%args
		}, $class);
	} else {
		return $class->temporary_model;
	}
}

=item C<< temporary_model >>
 
Returns a new temporary (non-persistent) model.
 
=cut
 
sub temporary_model {
	my $class	= shift;
	my $store	= RDF::Trine::Store::Memory->new();
# 	my $store	= RDF::Trine::Store::DBI->temporary_store();
	my $self	= $class->new( $store );
	$self->{temporary}	= 1;
	$self->{threshold}	= 25_000;
	return $self;
}

=item C<< dataset_model ( default => \@dgraphs, named => \@ngraphs ) >>

Returns a new model object with the default graph mapped to the union of the
graphs named in C<< @dgraphs >>, and with available named graphs named in
C<< @ngraphs >>.

=cut

sub dataset_model {
	my $self	= shift;
	my $ds		= RDF::Trine::Model::Dataset->new( $self );
	$ds->push_dataset( @_ );
	return $ds;
}

=item C<< begin_bulk_ops >>

Provides a hint to the backend that many update operations are about to occur.
The backend may use this hint to, for example, aggregate many operations into a
single operation, or delay index maintenence. After the update operations have
been executed, C<< end_bulk_ops >> should be called to ensure the updates are
committed to the backend.

=cut

sub begin_bulk_ops {
	my $self	= shift;
	my $store	= $self->_store;
	if (blessed($store) and $store->can('_begin_bulk_ops')) {
		$store->_begin_bulk_ops();
	}
}

=item C<< end_bulk_ops >>

Provides a hint to the backend that a set of bulk operations have been completed
and may be committed to the backend.

=cut

sub end_bulk_ops {
	my $self	= shift;
	my $store	= $self->_store;
	if (blessed($store) and $store->can('_end_bulk_ops')) {
		$store->_end_bulk_ops();
	}
}

=item C<< logger ( [ $logger ] ) >>

Returns the logging object responsible for recording data inserts and deletes.

If C<< $logger >> is passed as an argument, sets the logger to this object.

=cut

sub logger {
	my $self	= shift;
	if (scalar(@_)) {
		$self->{'logger'}	= shift;
	}
	return $self->{'logger'};
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<< $statement >> to the rdf store.

=cut
 
sub add_statement {
	my ($self, @args)	= @_;
	if ($args[0]->isa('RDF::Trine::Statement')) {
		foreach my $n ($args[0]->nodes) {
			unless (blessed($n) and ($n->isa('RDF::Trine::Node::Resource') or $n->isa('RDF::Trine::Node::Literal') or $n->isa('RDF::Trine::Node::Blank') or $n->isa('RDF::Trine::Node::Nil'))) {
				throw RDF::Trine::Error::MethodInvocationError -text => 'Cannot add a pattern (non-ground statement) to a model';
			}
		}
	} else {
		throw RDF::Trine::Error::MethodInvocationError -text => 'Argument is not an RDF::Trine::Statement';
	}
	if ($self->{temporary}) {
		if ($self->{added}++ >= $self->{threshold}) {
# 			warn "*** should upgrade to a DBI store here";
			my $store	= RDF::Trine::Store::DBI->temporary_store;
			my $iter	= $self->get_statements(undef, undef, undef, undef);
			if ($store->can('_begin_bulk_ops')) {
				$store->_begin_bulk_ops();
			}
			while (my $st = $iter->next) {
				$store->add_statement( $st );
			}
			if ($store->can('_begin_bulk_ops')) {
				$store->_end_bulk_ops();
			}
			$self->{store}	= $store;
			$self->{temporary}	= 0;
# 			warn "*** upgraded to a DBI store";
		}
	}
	
	if (my $log = $self->logger) {
		my ($st, $context)	= @args;
		if (defined($context)) {
			$st	= RDF::Trine::Statement::Quad->new(($st->nodes)[0..2], $context);
		}
		$log->add($st);
	}
	
	return $self->_store->add_statement( @args );
}

=item C<< add_hashref ( $hashref [, $context] ) >>

Add triples represented in an RDF/JSON-like manner to the model.

See C<< as_hashref >> for full documentation of the hashref format.

=cut

sub add_hashref {
	my $self	   = shift;
	my $index   = shift;
	my $context = shift;
	
	$self->begin_bulk_ops();
	foreach my $s (keys %$index) {
		my $ts = ( $s =~ /^_:(.*)$/ ) ?
					RDF::Trine::Node::Blank->new($1) :
					RDF::Trine::Node::Resource->new($s);
		
		foreach my $p (keys %{ $index->{$s} }) {
			my $tp = RDF::Trine::Node::Resource->new($p);
			
			foreach my $O (@{ $index->{$s}->{$p} }) {
				my $to;
				
				# $O should be a hashref, but we can do a little error-correcting.
				unless (ref $O) {
					if ($O =~ /^_:/) {
						$O = { 'value'=>$O, 'type'=>'bnode' };
					} elsif ($O =~ /^[a-z0-9._\+-]{1,12}:\S+$/i) {
						$O = { 'value'=>$O, 'type'=>'uri' };
					} elsif ($O =~ /^(.*)\@([a-z]{2})$/) {
						$O = { 'value'=>$1, 'type'=>'literal', 'lang'=>$2 };
					} else {
						$O = { 'value'=>$O, 'type'=>'literal' };
					}
				}
				
				if (lc $O->{'type'} eq 'literal') {
					$to = RDF::Trine::Node::Literal->new(
						$O->{'value'}, $O->{'lang'}, $O->{'datatype'});
				} else {
					$to = ( $O->{'value'} =~ /^_:(.*)$/ ) ?
						RDF::Trine::Node::Blank->new($1) :
						RDF::Trine::Node::Resource->new($O->{'value'});
				}
				
				if ($ts and $tp and $to) {
					my $st = RDF::Trine::Statement->new($ts, $tp, $to);
					$self->add_statement($st, $context);
				}
			}
		}
	}
	$self->end_bulk_ops();	
}

=item C<< add_iterator ( $iter ) >>

Add triples from the statement iterator to the model.

=cut

sub add_iterator {
	my $self	= shift;
	my $iter	= shift;
	unless (blessed($iter) and ($iter->is_graph)) {
		throw RDF::Trine::Error::MethodInvocationError -text => 'Cannot add a '. ref($iter) . ' iterator to a model, only graphs.';
	}
	$self->begin_bulk_ops();
	while (my $st = $iter->next) {
		$self->add_statement( $st );
	}
	$self->end_bulk_ops();	
}

=item C<< add_list ( @elements ) >>

Adds an rdf:List to the model with the given elements. Returns the node object
that is the head of the list.

=cut

sub add_list {
	my $self		= shift;
	my @elements	= @_;
	my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	if (scalar(@elements) == 0) {
		return $rdf->nil;
	} else {
		my $head		= RDF::Query::Node::Blank->new();
		my $node		= shift(@elements);
		my $rest		= $self->add_list( @elements );
		$self->add_statement( RDF::Trine::Statement->new($head, $rdf->first, $node) );
		$self->add_statement( RDF::Trine::Statement->new($head, $rdf->rest, $rest) );
		return $head;
	}
}

=item C<< get_list ( $head ) >>

Returns a list of nodes that are elements of the rdf:List represented by the
supplied head node.

=cut

sub get_list {
	my $self	= shift;
	my $head	= shift;
	my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	my @elements;
	my %seen;
	while (blessed($head) and not($head->isa('RDF::Trine::Node::Resource') and $head->uri_value eq $rdf->nil->uri_value)) {
		if ($seen{ $head->as_string }++) {
			throw RDF::Trine::Error -text => "Loop found during rdf:List traversal";
		}
		my @n		= $self->objects( $head, $rdf->first );
		if (scalar(@n) != 1) {
			throw RDF::Trine::Error -text => "Invalid structure found during rdf:List traversal";
		}
		push(@elements, @n);
		($head)	= $self->objects( $head, $rdf->rest );
	}
	return @elements;
}

=item C<< remove_list ( $head [, orphan_check => 1] ) >>

Removes the nodes of type rdf:List that make up the list. Optionally checks each node
before removal to make sure that it is not used in any other statements. Returns false
if the list was removed completely; returns the first remaining node if the removal
was abandoned because of an orphan check.

=cut

sub remove_list {
	my $self = shift;
	my $head = shift;
	my $rdf  = RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	my %args = @_;
	my %seen;
	
	while (blessed($head) and not($head->isa('RDF::Trine::Node::Resource') and $head->uri_value eq $rdf->nil->uri_value)) {
		if ($seen{ $head->as_string }++) {
			throw RDF::Trine::Error -text => "Loop found during rdf:List traversal";
		}
		my $stream = $self->get_statements($head, undef, undef);
		my %statements;
		while (my $st = $stream->next) {
			my $statement_type = {
				$rdf->first->uri  => 'rdf:first',
				$rdf->rest->uri   => 'rdf:rest',
				$rdf->type->uri   => 'rdf:type',
				}->{$st->predicate->uri} || 'other';
			$statement_type = 'other'
				if $statement_type eq 'rdf:type' && !$st->object->equal($rdf->List);
			push @{$statements{$statement_type}}, $st;
		}
		if ($args{orphan_check}) {
			return $head if defined $statements{other} && scalar(@{ $statements{other} }) > 0;
			return $head if $self->count_statements(undef, undef, $head) > 0;
		}
		unless (defined $statements{'rdf:first'} and defined $statements{'rdf:rest'} and scalar(@{$statements{'rdf:first'} })==1 and scalar(@{ $statements{'rdf:rest'} })==1) {
			throw RDF::Trine::Error -text => "Invalid structure found during rdf:List traversal";
		}
		$self->remove_statement($_)
			foreach (@{$statements{'rdf:first'}}, @{$statements{'rdf:rest'}}, @{$statements{'rdf:type'}});
		
		$head = $statements{'rdf:rest'}->[0]->object;
	}
	
	return;
}

=item C<< get_sequence ( $seq ) >>

Returns a list of nodes that are elements of the rdf:Seq sequence.

=cut

sub get_sequence {
	my $self	= shift;
	my $head	= shift;
	my $rdf		= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	my @elements;
	my $i		= 1;
	while (1) {
		my $method	= '_' . $i;
		my (@elem)	= $self->objects( $head, $rdf->$method() );
		unless (scalar(@elem)) {
			last;
		}
		if (scalar(@elem) > 1) {
			my $count	= scalar(@elem);
			throw RDF::Trine::Error -text => "Invalid structure found during rdf:Seq access: $count elements found for element $i";
		}
		my $elem	= $elem[0];
		last unless (blessed($elem));
		push(@elements, $elem);
		$i++;
	}
	return @elements;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<< $statement >> from the rdf store.

=cut

sub remove_statement {
	my $self	= shift;
	my @args	= @_;
	if (my $log = $self->logger) {
		my ($st, $context)	= @args;
		if (defined($context)) {
			$st	= RDF::Trine::Statement::Quad->new(($st->nodes)[0..2], $context);
		}
		$log->delete($st);
	}
	return $self->_store->remove_statement( @args );
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context] ) >>

Removes all statements matching the supplied C<< $statement >> pattern from the rdf store.

=cut

sub remove_statements {
	my $self	= shift;
	if (my $log = $self->logger) {
		$log->delete($_) foreach (@_);
	}
	return $self->_store->remove_statements( @_ );
}

=item C<< size >>

Returns the number of statements in the model.

=cut

sub size {
	my $self	= shift;
	$self->end_bulk_ops();
	return $self->count_statements(undef, undef, undef, undef);
}

=item C<< etag >>

If the model is based on a store that has the capability and knowledge to
support caching, this method returns a persistent token that will remain
consistent as long as the store's data doesn't change. This token is acceptable
for use as an HTTP ETag.

=cut

sub etag {
	my $self	= shift;
	my $store	= $self->_store;
	if ($store) {
		return $store->etag;
	}
	return;
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
underlying store, false otherwise. If C<< $feature >> is not specified, returns
a list of supported features.

=cut

sub supports {
	my $self	= shift;
	my $store	= $self->_store;
	if ($store) {
		return $store->supports( @_ );
	}
	return;
}

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	$self->end_bulk_ops();

	if (scalar(@_) >= 4) {
		my $graph	= $_[3];
		if (blessed($graph) and $graph->isa('RDF::Trine::Node::Resource') and $graph->uri_value eq 'tag:gwilliams@cpan.org,2010-01-01:RT:ALL') {
			$_[3]	= undef;
		}
	}
	return $self->_store->count_statements( @_ );
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns an L<iterator|RDF::Trine::Iterator> of all statements matching the specified 
subject, predicate and objects from the rdf store. Any of the arguments may be undef 
to match any value.

If three or fewer arguments are given, the statements returned will be matched
based on triple semantics (the graph union of triples from all the named
graphs). If four arguments are given (even if C<< $context >> is undef),
statements will be matched based on quad semantics (the union of all quads in
the underlying store).

=cut

sub get_statements {
	my $self	= shift;
	$self->end_bulk_ops();
	
	my @pos	= qw(subject predicate object graph);
	foreach my $i (0 .. $#_) {
		my $n	= $_[$i];
		next unless defined($n);	# undef is OK
		next if (blessed($n) and $n->isa('RDF::Trine::Node'));	# node objects are OK
		my $pos	= $pos[$i];
		local($Data::Dumper::Indent)	= 0;
		my $ser	= Data::Dumper->Dump([$n], [$pos]);
		throw RDF::Trine::Error::MethodInvocationError -text => "get_statements called with a value that isn't undef or a node object: $ser";
	}
	
	if (scalar(@_) >= 4) {
		my $graph	= $_[3];
		if (blessed($graph) and $graph->isa('RDF::Trine::Node::Resource') and $graph->uri_value eq 'tag:gwilliams@cpan.org,2010-01-01:RT:ALL') {
			$_[3]	= undef;
		}
	}
	return $self->_store->get_statements( @_ );
}

=item C<< get_pattern ( $bgp [, $context] [, %args ] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

If C<< $context >> is given, restricts BGP matching to only quads with the
C<< $context >> value.

C<< %args >> may contain an 'orderby' key-value pair to request a specific
ordering based on variable name. The value for the 'orderby' key should be an
ARRAY reference containing variable name and direction ('ASC' or 'DESC') tuples.
A valid C<< %args >> hash, therefore, might look like
C<< orderby => [qw(name ASC)] >> (corresponding to a SPARQL-like request to
'ORDER BY ASC(?name)').

=cut

sub get_pattern {
	my $self	= shift;
	my $bgp		= shift;
	my $context	= shift;
	my @args	= @_;
	my %args	= @args;
	
	$self->end_bulk_ops();
	my (@triples)	= ($bgp->isa('RDF::Trine::Statement') or $bgp->isa('RDF::Query::Algebra::Filter'))
					? $bgp
					: $bgp->triples;
	unless (@triples) {
		throw RDF::Trine::Error::CompilationError -text => 'Cannot call get_pattern() with empty pattern';
	}
	
	my $store	= $self->_store;
	# while almost all models will delegate get_pattern() to the underlying
	# store object, in some cases this isn't possible (union models don't have
	# a single store, so have to fall back to the model-specific get_pattern()
	# implementation).
	if (blessed($store) and $store->can('get_pattern')) {
		return $self->_store->get_pattern( $bgp, $context, @args );
	} else {
		if ($bgp->isa('RDF::Trine::Pattern')) {
			$bgp	= $bgp->sort_for_join_variables();
		}
		my $iter	= $self->_get_pattern( $bgp, $context );
		if (my $ob = $args{orderby}) {
			my @order	= @$ob;
			if (scalar(@order) % 2) {
				throw RDF::Trine::Error::MethodInvocationError -text => "Invalid arguments to orderby argument in get_pattern";
			}
			
			my @results	= $iter->get_all();
			my $order_vars	= scalar(@order) / 2;
			my %seen;
			foreach my $r (@results) {
				foreach my $var (keys %$r) {
					$seen{$var}++;
				}
			}
			
			@results	= sort {
				my $r	= 0;
				foreach my $i (0 .. ($order_vars-1)) {
					my $var	= $order[$i*2];
					my $rev	= ($order[$i*2+1] =~ /DESC/i);
					$r	= RDF::Trine::Node::compare( $a->{$var}, $b->{$var} );
					$r	*= -1 if ($rev);
					last if ($r);
				}
				$r;
			} @results;
			
			my @sortedby;
			foreach my $i (0 .. ($order_vars-1)) {
				my $var	= $order[$i*2];
				my $dir	= $order[$i*2+1];
				push(@sortedby, $var, $dir) if ($seen{$var});
			}
			$iter	= RDF::Trine::Iterator::Bindings->new(\@results, undef, sorted_by => \@sortedby);
		}
		return $iter;
	}
}

=item C<< get_sparql ( $sparql ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_sparql {
	my $self	= shift;
	return $self->_store->get_sparql( @_ );
}

sub _get_pattern {
	my $self	= shift;
	my $bgp		= shift;
	my $context	= shift;
	my @args	= @_;
	
	my (@triples)	= ($bgp->isa('RDF::Trine::Statement') or $bgp->isa('RDF::Query::Algebra::Filter'))
					? $bgp
					: $bgp->triples;
	if (1 == scalar(@triples)) {
		my $t		= shift(@triples);
		my @nodes	= $t->nodes;
		my %vars;
		my @names	= qw(subject predicate object context);
		foreach my $n (0 .. $#nodes) {
			if ($nodes[$n]->isa('RDF::Trine::Node::Variable')) {
				$vars{ $names[ $n ] }	= $nodes[$n]->name;
			}
		}
		if ($context) {
			$nodes[3]	= $context;
		}
		my $iter	= $self->get_statements( @nodes );
		my @vars	= values %vars;
		my $sub		= sub {
			my $row	= $iter->next;
			return unless ($row);
			my %data	= map { $vars{ $_ } => $row->$_() } (keys %vars);
			return RDF::Trine::VariableBindings->new( \%data );
		};
		return RDF::Trine::Iterator::Bindings->new( $sub, \@vars );
	} else {
		my $t		= pop(@triples);
		my $rhs	= $self->_get_pattern( RDF::Trine::Pattern->new( $t ), $context, @args );
		my $lhs	= $self->_get_pattern( RDF::Trine::Pattern->new( @triples ), $context, @args );
		my @inner;
		while (my $row = $rhs->next) {
			push(@inner, $row);
		}
		my @results;
		while (my $row = $lhs->next) {
			RESULT: foreach my $irow (@inner) {
				my %keysa;
				my @keysa	= keys %$irow;
				@keysa{ @keysa }	= (1) x scalar(@keysa);
				my @shared	= grep { exists $keysa{ $_ } } (keys %$row);
				foreach my $key (@shared) {
					my $val_a	= $irow->{ $key };
					my $val_b	= $row->{ $key };
					next unless (defined($val_a) and defined($val_b));
					my $equal	= $val_a->equal( $val_b );
					unless ($equal) {
						next RESULT;
					}
				}
				
				my $jrow	= { (map { $_ => $irow->{$_} } grep { defined($irow->{$_}) } keys %$irow), (map { $_ => $row->{$_} } grep { defined($row->{$_}) } keys %$row) };
				push(@results, RDF::Trine::VariableBindings->new($jrow));
			}
		}
		my $result	= RDF::Trine::Iterator::Bindings->new( \@results, [ $bgp->referenced_variables ] );
		return $result;
	}
}

=item C<< get_graphs >>

=item C<< get_contexts >>

Returns an L<iterator|RDF::Trine::Iterator> containing the nodes representing 
the named graphs in the model.

=cut

sub get_contexts {
	my $self	= shift;
	my $store	= $self->_store;
	$self->end_bulk_ops();
	my $iter	= $store->get_contexts( @_ );
	if (wantarray) {
		return $iter->get_all;
	} else {
		return $iter;
	}
}
*get_graphs = \&get_contexts;

=item C<< as_stream >>

Returns an L<iterator|RDF::Trine::Iterator> containing every statement in the model.

=cut

sub as_stream {
	my $self	= shift;
	$self->end_bulk_ops();
	my $st		= RDF::Trine::Statement::Quad->new( map { variable($_) } qw(s p o g) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $self->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $stream->as_statements( qw(s p o g) );
}

=item C<< as_hashref >>

Returns a hashref representing the model in an RDF/JSON-like manner.

A graph like this (in Turtle):

  @prefix ex: <http://example.com/> .
  
  ex:subject1
    ex:predicate1
      "Foo"@en ,
      "Bar"^^ex:datatype1 .
  
  _:bnode1
    ex:predicate2
      ex:object2 ;
    ex:predicate3 ;
      _:bnode3 .

Is represented like this as a hashref:

  {
    "http://example.com/subject1" => {
      "http://example.com/predicate1" => [
        { 'type'=>'literal', 'value'=>"Foo", 'lang'=>"en" },
        { 'type'=>'literal', 'value'=>"Bar", 'datatype'=>"http://example.com/datatype1" },
      ],
    },
    "_:bnode1" => {
      "http://example.com/predicate2" => [
        { 'type'=>'uri', 'value'=>"http://example.com/object2" },
      ],
      "http://example.com/predicate2" => [
        { 'type'=>'bnode', 'value'=>"_:bnode3" },
      ],
    },
  }

Note that the type of subjects (resource or blank node) is indicated
entirely by the convention of starting blank nodes with "_:".

This hashref structure is compatible with RDF/JSON and with the ARC2
library for PHP.

=cut

sub as_hashref {
	my $self	= shift;
	$self->end_bulk_ops();
	return $self->as_stream->as_hashref;
}

=item C<< as_graphviz >>

Returns a L<GraphViz> object of the RDF graph of this model, ignoring graph
names/contexts.

This method will attempt to load the L<GraphViz> module at runtime and will fail
if the module is unavailable.

=cut

sub as_graphviz {
	my $self	= shift;
	require GraphViz;
	my $g	= GraphViz->new();
	my %seen;
	my $iter	= $self->as_stream;
	while (my $t = $iter->next) {
		my @nodes;
		foreach my $pos (qw(subject object)) {
			my $n	= $t->$pos();
			my $label	= ($n->isa('RDF::Trine::Node::Literal')) ? $n->literal_value : $n->as_string;
			push(@nodes, $label);
			unless ($seen{ $label }++) {
				$g->add_node( $label );
			}
		}
		$g->add_edge( @nodes, label => $t->predicate->as_string );
	}
	return $g;
}

=back

=head2 Node-Centric Graph API

=over 4

=item C<< subjects ( $predicate, $object ) >>

Returns a list of the nodes that appear as the subject of statements with the
specified C<< $predicate >> and C<< $object >>. Either of the two arguments may
be undef to signify a wildcard.

=cut

sub subjects {
	my $self	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $graph	= shift;
	$self->end_bulk_ops();
	my $iter	= $self->get_statements( undef, $pred, $obj, $graph );
	my %nodes;
	while (my $st = $iter->next) {
		my $subj	= $st->subject;
		$nodes{ $subj->as_string }	= $subj;
	}
	if (wantarray) {
		return values(%nodes);
	} else {
		return RDF::Trine::Iterator->new( [values(%nodes)] );
	}
}

=item C<< predicates ( $subject, $object ) >>

Returns a list of the nodes that appear as the predicate of statements with the
specified C<< $subject >> and C<< $object >>. Either of the two arguments may
be undef to signify a wildcard.

=cut

sub predicates {
	my $self	= shift;
	my $subj	= shift;
	my $obj		= shift;
	my $graph	= shift;
	$self->end_bulk_ops();
	my $iter	= $self->get_statements( $subj, undef, $obj, $graph );
	my %nodes;
	while (my $st = $iter->next) {
		my $pred	= $st->predicate;
		$nodes{ $pred->as_string }	= $pred;
	}
	if (wantarray) {
		return values(%nodes);
	} else {
		return RDF::Trine::Iterator->new( [values(%nodes)] );
	}
}

=item C<< objects ( $subject, $predicate [, $graph ] [, %options ] ) >>

Returns a list of the nodes that appear as the object of statements with the
specified C<< $subject >> and C<< $predicate >>. Either of the two arguments 
may be undef to signify a wildcard. You can further filter objects using the
C<< %options >> argument. Keys in C<< %options >> indicate the restriction type
and may be 'type', 'language', or 'datatype'. The value of the 'type' key may be
one of 'node', 'nil', 'blank', 'resource', 'literal', or 'variable'. The use of
either 'language' or 'datatype' restrict objects to literal nodes with a
specific language or datatype value, respectively.

=cut

sub objects {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my ($graph, %options)	= (@_ % 2 == 0) ? (undef, @_) : @_;
	my $type	= $options{type};
	$type = 'literal' if ($options{language} or $options{datatype});
	if ($options{datatype} and not blessed($options{datatype})) {
		$options{datatype} = RDF::Trine::Node::Resource->new($options{datatype});
	}
	
	if (defined $type) {
		if ($type =~ /^(node|nil|blank|resource|literal|variable)$/) {
			$type = "is_$type";
		} else {
			throw RDF::Trine::Error::CompilationError -text => "unknown type"
		}
	}
	$self->end_bulk_ops();
	my $iter	= $self->get_statements( $subj, $pred, undef, $graph );
	my %nodes;
	while (my $st = $iter->next) {
		my $obj = $st->object;
		if (defined $type) {
			next unless $obj->$type;
			if ($options{language}) {
				my $lang = $obj->literal_value_language;
				next unless ($lang and $lang eq $options{language});
			} elsif ($options{datatype}) {
				my $dt = $obj->literal_datatype;
				next unless ($dt and $dt eq $options{datatype}->uri_value);
			}
		}
		$nodes{ $obj->as_string }	= $obj;
	}
	if (wantarray) {
		return values(%nodes);
	} else {
		return RDF::Trine::Iterator->new( [values(%nodes)] );
	}
}

=item C<< objects_for_predicate_list ( $subject, @predicates ) >>

Given the RDF::Trine::Node objects C<< $subject >> and C<< @predicates >>,
finds all matching triples in the model with the specified subject and any
of the given predicates, and returns a list of object values (in the partial
order given by the ordering of C<< @predicates >>).

=cut

sub objects_for_predicate_list {
	my $self	= shift;
	my $node	= shift;
	my @preds	= @_;
	$self->end_bulk_ops();
	my @objects;
	foreach my $p (@preds) {
		my $iter	= $self->get_statements( $node, $p );
		while (my $s = $iter->next) {
			if (not(wantarray)) {
				return $s->object;
			} else {
				push( @objects, $s->object );
			}
		}
	}
	return @objects;
}

=item C<< bounded_description ( $node ) >>

Returns an RDF::Trine::Iterator::Graph object over the bounded description
triples for C<< $node >> (all triples resulting from a graph traversal starting
with C<< node >> and stopping at non-blank nodes).

=cut

sub bounded_description {
	my $self	= shift;
	my $node	= shift;
	$self->end_bulk_ops();
	my %seen;
	my @nodes	= $node;
	my @statements;
	my $sub		= sub {
		return if (not(@statements) and not(@nodes));
		while (1) {
			if (not(@statements)) {
				my $l = Log::Log4perl->get_logger("rdf.trine.model");
				return unless (scalar(@nodes));
				my $n	= shift(@nodes);
# 				warn "CBD handling node " . $n->sse . "\n";
				next if ($seen{ $n->sse });
				try {
					my $st		= RDF::Trine::Statement->new( $n, map { variable($_) } qw(p o) );
					my $pat		= RDF::Trine::Pattern->new( $st );
					my $sts		= $self->get_pattern( $pat, undef, orderby => [ qw(p ASC o ASC) ] );
# 					my $sts		= $stream->as_statements( qw(s p o) );
# 					my $sts	= $self->get_statements( $n );
					my @s	= grep { not($seen{$_->{'o'}->sse}) } $sts->get_all;
# 					warn "+ " . $_->as_string . "\n" for (@s);
					push(@statements, map { RDF::Trine::Statement->new($n, @{ $_ }{qw(p o)}) } @s);
				} catch RDF::Trine::Error::UnimplementedError with {
					$l->debug('[model] Ignored UnimplementedError in bounded_description: ' . $_[0]->{'-text'});
				};
				try {
					my $st		= RDF::Trine::Statement->new( (map { variable($_) } qw(s p)), $n );
					my $pat		= RDF::Trine::Pattern->new( $st );
					my $sts		= $self->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC) ] );
# 					my $sts		= $stream->as_statements( qw(s p o) );
# 					my $sts	= $self->get_statements( undef, undef, $n );
					my @s	= grep { not($seen{$_->{'s'}->sse}) and not($_->{'s'}->equal($n)) } $sts->get_all;
# 					warn "- " . $_->as_string . "\n" for (@s);
					push(@statements, map { RDF::Trine::Statement->new(@{ $_ }{qw(s p)}, $n) } @s);
				} catch RDF::Trine::Error::UnimplementedError with {
					$l->debug('[model] Ignored UnimplementedError in bounded_description: ' . $_[0]->{'-text'});
				};
				$seen{ $n->sse }++
			}
			last if (scalar(@statements));
		}
		return unless (scalar(@statements));
		my $st	= shift(@statements);
		if ($st->object->isa('RDF::Trine::Node::Blank') and not($seen{ $st->object->sse })) {
# 			warn "+ CBD pushing " . $st->object->sse . "\n";
			push(@nodes, $st->object);
		}
		if ($st->subject->isa('RDF::Trine::Node::Blank') and not($seen{ $st->subject->sse })) {
# 			warn "- CBD pushing " . $st->subject->sse . "\n";
			push(@nodes, $st->subject);
		}
		return $st;
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< as_string >>

=cut

sub as_string {
	my $self	= shift;
	$self->end_bulk_ops();
	my $iter	= $self->get_statements( undef, undef, undef, undef );
	my @rows;
	my @names	= qw[subject predicate object context];
	while (my $row = $iter->next) {
		push(@rows, [map {$row->$_()->as_string} @names]);
	}
	my @rule			= qw(- +);
	my @headers			= (\q"| ");
	push(@headers, map { $_ => \q" | " } @names);
	pop	@headers;
	push @headers => (\q" |");
	my $table = Text::Table->new(@names);
	$table->rule(@rule);
	$table->body_rule(@rule);
	$table->load(@rows);
	my $size	= scalar(@rows);
	return join('',
			$table->rule(@rule),
			$table->title,
			$table->rule(@rule),
			map({ $table->body($_) } 0 .. @rows),
			$table->rule(@rule)
		) . "$size statements\n";
}

sub _store {
	my $self	= shift;
	return $self->{store};
}

sub _debug {
	my $self	= shift;
	my $warn	= shift;
	my $stream	= $self->get_statements( undef, undef, undef, undef );
	my $l		= Log::Log4perl->get_logger("rdf.trine.model");
	$l->debug( 'model statements:' );
	if ($warn) {
		warn "Model $self:\n";
	}
	my $count	= 0;
	while (my $s = $stream->next) {
		$count++;
		if ($warn) {
			warn $s->as_string . "\n";
		}
		$l->debug('[model]' . $s->as_string);
	}
	if ($warn) {
		warn "$count statements\n";
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
