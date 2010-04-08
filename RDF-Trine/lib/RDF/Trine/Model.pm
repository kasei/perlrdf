# RDF::Trine::Model
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model - Model class

=head1 VERSION

This document describes RDF::Trine::Model version 0.119_01

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model;

use strict;
use warnings;
no warnings 'redefine';

our ($VERSION);
BEGIN {
	$VERSION	= '0.119_01';
}

use Scalar::Util qw(blessed);
use Log::Log4perl;

use RDF::Trine qw(variable);
use RDF::Trine::Node;
use RDF::Trine::Pattern;
use RDF::Trine::Store::DBI;

=item C<< new ( @stores ) >>

Returns a new model over the supplied rdf store.

=cut

sub new {
	my $class	= shift;
	my $store	= shift;
	my %args	= @_;
	my $self	= bless({
		store		=> $store,
		temporary	=> 0,
		added		=> 0,
		threshold	=> -1,
		%args
	}, $class);
}

=item C<< temporary_model >>
 
Returns a new temporary (non-persistent) model.
 
=cut
 
sub temporary_model {
	my $class	= shift;
	my $store	= RDF::Trine::Store::Memory->new();
	my $self	= $class->new( $store );
	$self->{temporary}	= 1;
	$self->{threshold}	= 2000;
	return $self;
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
			my $iter	= $self->get_statements();
			while (my $st = $iter->next) {
				$store->add_statement( $st );
			}
			$self->{store}	= $store;
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
	return $self->count_statements();
}

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	return $self->_store->count_statements( @_ );
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects from the rdf store. Any of the arguments may be undef to
match any value.

=cut

sub get_statements {
	my $self	= shift;
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
	
	my (@triples)	= ($bgp->isa('RDF::Trine::Statement') or $bgp->isa('RDF::Query::Algebra::Filter'))
					? $bgp
					: $bgp->triples;
	unless (@triples) {
		throw RDF::Trine::Error::CompilationError -text => 'Cannot call get_pattern() with empty pattern';
	}
	
	my $store	= $self->_store;
	if ($store and $store->can('get_pattern')) {
		return $self->_store->get_pattern( $bgp, $context, @args );
	} else {
		if (1 == scalar(@triples)) {
			my $t		= shift(@triples);
			my @nodes	= $t->nodes;
			my %vars;
			my @names	= qw(subject predicate object);
			foreach my $n (0 .. 2) {
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
				return \%data;
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
					push(@results, $jrow);
				}
			}
			return RDF::Trine::Iterator::Bindings->new( \@results, [ $bgp->referenced_variables ] );
		}
	}
}

=item C<< get_contexts >>

=cut

sub get_contexts {
	my $self	= shift;
	my $store	= $self->_store;
	return $store->get_contexts( @_ );
}

=item C<< as_stream >>

Returns an iterator object containing every statement in the model.

=cut

sub as_stream {
	my $self	= shift;
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
	my $stream	= $self->as_stream;
	my $index = {};
	while (my $statement = $stream->next) {
		
		my $s = $statement->subject->is_blank ? 
			('_:'.$statement->subject->blank_identifier) :
			$statement->subject->uri ;
		my $p = $statement->predicate->uri ;
		
		my $o = {};
		if ($statement->object->is_literal) {
			$o->{'type'}     = 'literal';
			$o->{'value'}    = $statement->object->literal_value;
			$o->{'lang'}     = $statement->object->literal_value_language
				if $statement->object->has_language;
			$o->{'datatype'} = $statement->object->literal_datatype
				if $statement->object->has_datatype;
		} else {
			$o->{'type'}  = $statement->object->is_blank ? 'bnode' : 'uri';
			$o->{'value'} = $statement->object->is_blank ? 
				('_:'.$statement->object->blank_identifier) :
				$statement->object->uri ;
		}

		push @{ $index->{$s}->{$p} }, $o;
	}
	return $index;
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

sub _store {
	my $self	= shift;
	return $self->{store};
}

sub _debug {
	my $self	= shift;
	my $stream	= $self->get_statements( undef, undef, undef, undef );
	my $l		= Log::Log4perl->get_logger("rdf.trine.model");
	$l->debug( 'model statements:' );
	while (my $s = $stream->next) {
		$l->debug('[model]' . $s->as_string);
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
