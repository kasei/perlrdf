# RDF::Trine::Model
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model - Model class

=head1 VERSION

This document describes RDF::Trine::Model version 0.129_01

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model;

use strict;
use warnings;
no warnings 'redefine';

our ($VERSION);
BEGIN {
	$VERSION	= '0.129_01';
}

use Scalar::Util qw(blessed);
use Log::Log4perl;

use RDF::Trine::Error qw(:try);
use RDF::Trine qw(variable);
use RDF::Trine::Node;
use RDF::Trine::Pattern;
use RDF::Trine::Store::DBI;
use RDF::Trine::Model::Dataset;

=item C<< new ( @stores ) >>

Returns a new model over the supplied rdf store.

=cut

sub new {
	my $class	= shift;
	if (@_) {
		my $store	= shift;
		throw RDF::Trine::Error -text => "no store in model constructor" unless (blessed($store));
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

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<< $statement >> to the rdf store.

=cut
 
sub add_statement {
	my $self	= shift;
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
			if ($store->can('_end_bulk_ops')) {
				$store->_end_bulk_ops();
			}
			$self->{store}	= $store;
			$self->{temporary}	= 0;
# 			warn "*** upgraded to a DBI store";
		}
	}
	return $self->_store->add_statement( @_ );
}

=item C<< add_hashref ( $hashref [, $context] ) >>

Add triples represented in an RDF/JSON-like manner to the model.

See C<< as_hashref >> for full documentation of the hashref format.

=cut

sub add_hashref {
	my $self	   = shift;
	my $index   = shift;
	my $context = shift;
	
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
				
				if ( $ts && $tp && $to ) {
					my $st = RDF::Trine::Statement->new($ts, $tp, $to);
					$self->add_statement($st, $context);
				}
			}
		}
	}
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<< $statement >> from the rdf store.

=cut

sub remove_statement {
	my $self	= shift;
	return $self->_store->remove_statement( @_ );
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context] ) >>

Removes all statements matching the supplied C<< $statement >> pattern from the rdf store.

=cut

sub remove_statements {
	my $self	= shift;
	return $self->_store->remove_statements( @_ );
}

=item C<< size >>

Returns the number of statements in the model.

=cut

sub size {
	my $self	= shift;
	$self->end_bulk_ops();
	return $self->count_statements();
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

Returns an iterator of all statements matching the specified subject,
predicate and objects from the rdf store. Any of the arguments may be undef to
match any value.

If three or fewer arguments are given, the statements returned will be matched
based on triple semantics (the graph union of triples from all the named
graphs). If four arguments are given (even if C<< $context >> is undef),
statements will be matched based on quad semantics (the union of all quads in
the underlying store).

=cut

sub get_statements {
	my $self	= shift;
	$self->end_bulk_ops();
	
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
		return $self->_get_pattern( $bgp, $context, @args );
	}
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
		my $iter	= $self->get_statements( @nodes, $context, @args );
		my @vars	= values %vars;
		my $sub		= sub {
			my $row	= $iter->next;
			return undef unless ($row);
			my %data	= map { $vars{ $_ } => $row->$_() } (keys %vars);
			return RDF::Trine::VariableBindings->new( \%data );
		};
		return RDF::Trine::Iterator::Bindings->new( $sub, \@vars );
	} else {
		my $t		= shift(@triples);
		my $rhs	= $self->get_pattern( RDF::Trine::Pattern->new( $t ), $context, @args );
		my $lhs	= $self->get_pattern( RDF::Trine::Pattern->new( @triples ), $context, @args );
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

=item C<< get_contexts >>

Returns an iterator containing the nodes representing the named graphs in the
model.

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

=item C<< as_stream >>

Returns an iterator object containing every statement in the model.

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
	my $stream	= $self->as_stream;
	my $index = {};
	while (my $statement = $stream->next) {
		
		my $s = $statement->subject->isa('RDF::Trine::Node::Blank') ? 
			('_:'.$statement->subject->blank_identifier) :
			$statement->subject->uri ;
		my $p = $statement->predicate->uri ;
		
		my $o = {};
		if ($statement->object->isa('RDF::Trine::Node::Literal')) {
			$o->{'type'}     = 'literal';
			$o->{'value'}    = $statement->object->literal_value;
			$o->{'lang'}     = $statement->object->literal_value_language
				if $statement->object->has_language;
			$o->{'datatype'} = $statement->object->literal_datatype
				if $statement->object->has_datatype;
		} else {
			$o->{'type'}  = $statement->object->isa('RDF::Trine::Node::Blank') ? 'bnode' : 'uri';
			$o->{'value'} = $statement->object->isa('RDF::Trine::Node::Blank') ? 
				('_:'.$statement->object->blank_identifier) :
				$statement->object->uri ;
		}

		push @{ $index->{$s}->{$p} }, $o;
	}
	return $index;
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

=item C<< objects ( $subject, $predicate ) >>

Returns a list of the nodes that appear as the object of statements with the
specified C<< $subject >> and C<< $predicate >>. Either of the two arguments may
be undef to signify a wildcard.

=cut

sub objects {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $graph	= shift;
	$self->end_bulk_ops();
	my $iter	= $self->get_statements( $subj, $pred, undef, $graph );
	my %nodes;
	while (my $st = $iter->next) {
		my $obj	= $st->object;
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
					my $sts	= $self->get_statements( $n );
					my @s	= grep { not($seen{$_->object->sse}) } $sts->get_all;
# 					warn "+ " . $_->sse . "\n" for (@s);
					push(@statements, @s);
				} catch RDF::Trine::Error::UnimplementedError with {
					$l->debug('[model] Ignored UnimplementedError in bounded_description: ' . $_[0]->{'-text'});
				};
				try {
					my $sts	= $self->get_statements( undef, undef, $n );
					my @s	= grep { not($seen{$_->subject->sse}) and not($_->subject->equal($n)) } $sts->get_all;
# 					warn "- " . $_->sse . "\n" for (@s);
					push(@statements, @s);
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

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
