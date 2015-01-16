# RDF::Trine::Serializer::Turtle
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::Turtle - Turtle Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::Turtle version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Serializer::Turtle;
 my $serializer	= RDF::Trine::Serializer::Turtle->new( namespaces => { ex => 'http://example/' } );
 print $serializer->serialize_model_to_string($model);

=head1 DESCRIPTION

The RDF::Trine::Serializer::Turtle class provides an API for serializing RDF
graphs to the Turtle syntax. XSD numeric types are serialized as bare literals,
and where possible the more concise syntax is used for rdf:Lists.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::Turtle;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use Encode;
use Data::Dumper;
use Scalar::Util qw(blessed refaddr reftype);

use RDF::Trine qw(variable iri);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);
use RDF::Trine::Namespace qw(rdf);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '1.012';
	$RDF::Trine::Serializer::serializer_names{ 'turtle' }	= __PACKAGE__;
	$RDF::Trine::Serializer::format_uris{ 'http://www.w3.org/ns/formats/Turtle' }	= __PACKAGE__;
	foreach my $type (qw(application/x-turtle application/turtle text/turtle text/rdf+n3)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new ( namespaces => \%namespaces, base_uri => $base_uri ) >>

Returns a new Turtle serializer object.

=cut

sub new {
	my $class	= shift;
	my $ns	= {};
	my $base_uri;

	if (@_) {
		if (scalar(@_) == 1 and reftype($_[0]) eq 'HASH') {
			$ns	= shift;
		} else {
			my %args	= @_;
			if (exists $args{ base }) {
				$base_uri   = $args{ base };
			}
			if (exists $args{ base_uri }) {
				$base_uri   = $args{ base_uri };
			}
			if (exists $args{ namespaces }) {
				$ns	= $args{ namespaces };
			}
		}
	}

	my %rev;
    if (blessed($ns) and $ns->isa('RDF::Trine::NamespaceMap')) {
        for my $prefix ($ns->list_prefixes) {
            # way convoluted
            my $nsuri = $ns->namespace_uri($prefix)->uri->value;
            $rev{$nsuri} = $prefix;
        }
    }
    else {
        while (my ($ns, $uri) = each(%{ $ns })) {
            if (blessed($uri)) {
                $uri	= $uri->uri_value;
                if (blessed($uri)) {
                    $uri	= $uri->uri_value;
                }
            }
            $rev{ $uri }	= $ns;
        }
	}

	my $self = bless( {
		ns		=> \%rev,
		base_uri	=> $base_uri,
	}, $class );
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to Turtle, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $model	= shift;
	my $sink	= RDF::Trine::Serializer::FileSink->new($fh);
	
	my $st		= RDF::Trine::Statement->new( map { variable($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	$self->serialize_iterator( $sink, $iter, seen => {}, level => 0, tab => "\t", @_, model => $model );
	return 1;
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to Turtle, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $sink	= RDF::Trine::Serializer::StringSink->new();

	my $st		= RDF::Trine::Statement->new( map { variable($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	$self->serialize_iterator( $sink, $iter, seen => {}, level => 0, tab => "\t", @_, model => $model, string => 1 );
	return $sink->string;
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to Turtle, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $iter	= shift;
	my %args	= @_;

	my $sink	= RDF::Trine::Serializer::FileSink->new($fh);
	$self->serialize_iterator( $sink, $iter, %args );
	return 1;
}

=item C<< serialize_iterator ( $sink, $iter ) >>

Serializes the iterator to Turtle, printing the results to the supplied
sink object.

=cut

sub serialize_iterator {
	my $self	= shift;
	my $sink	= shift;
	my $iter	= shift;
	my %args	= @_;
	
	my $seen	= $args{ seen } || {};
	my $level	= $args{ level } || 0;
	my $tab		= $args{ tab } || "\t";
	my $indent	= $tab x $level;
	
	my %ns		= reverse(%{ $self->{ns} });
	my @nskeys	= sort keys %ns;
	
	unless ($sink->can('prepend')) {
		if (@nskeys) {
			foreach my $ns (sort @nskeys) {
				my $uri	= $ns{ $ns };
				$sink->emit("\@prefix $ns: <$uri> .\n");
			}
			$sink->emit("\n");
		}
	}
	if ($self->{base_uri}) {
		$sink->emit("\@base <$self->{base_uri}> .\n\n");
	}
	
	my $last_subj;
	my $last_pred;
	
	my $open_triple	= 0;
	while (my $st = $iter->next) {
# 		warn "------------------\n";
# 		warn $st->as_string . "\n";
		my $subj	= $st->subject;
		my $pred	= $st->predicate;
		my $obj		= $st->object;
		
		# we're abusing the seen hash here as the key isn't really a node value,
		# but since it isn't a valid node string being used it shouldn't collide
		# with real data. we set this here so that later on when we check for
		# single-owner bnodes (when attempting to use the [...] concise syntax),
		# bnodes that have already been serialized as the 'head' of a statement
		# aren't considered as single-owner. This is because the output string
		# is acting as a second ownder of the node -- it's already been emitted
		# as something like '_:foobar', so it can't also be output as '[...]'.
		$seen->{ '  heads' }{ $subj->as_string }++;
		
		if (my $model = $args{model}) {
			if (my $head = $self->_statement_describes_list($model, $st)) {
				warn "found a rdf:List head " . $head->as_string . " for the subject in statement " . $st->as_string if ($debug);
				if ($model->count_statements(undef, undef, $head)) {
					# the rdf:List appears as the object of a statement, and so
					# will be serialized whenever we get to serializing that
					# statement
					warn "next" if ($debug);
					next;
				}
			}
		}
		
		if ($seen->{ $subj->as_string }) {
			warn "next on seen subject " . $st->as_string if ($debug);
			next;
		}
		
		if ($subj->equal( $last_subj )) {
			# continue an existing subject
			if ($pred->equal( $last_pred )) {
				# continue an existing predicate
				$sink->emit(qq[, ]);
				$self->_serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
			} else {
				# start a new predicate
				$sink->emit(qq[ ;\n${indent}$tab]);
				$self->_turtle( $sink, $pred, 1, $seen, $level, $tab, %args );
				$sink->emit(' ');
				$self->_serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				$sink->emit(qq[ .\n${indent}]);
			}
			$open_triple	= 1;
			$self->_turtle( $sink, $subj, 0, $seen, $level, $tab, %args );
			
			warn '-> ' . $pred->as_string if ($debug);
			$sink->emit(' ');
			$self->_turtle( $sink, $pred, 1, $seen, $level, $tab, %args );
			$sink->emit(' ');
			$self->_serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
		}
	} continue {
		if (blessed($last_subj) and not($last_subj->equal($st->subject))) {
# 			warn "marking " . $st->subject->as_string . " as seen";
			$seen->{ $last_subj->as_string }++;
		}
# 		warn "setting last subject to " . $st->subject->as_string;
		$last_subj	= $st->subject;
		$last_pred	= $st->predicate;
	}
	
	if ($open_triple) {
		$sink->emit(qq[ .\n]);
	}
	
	if ($sink->can('prepend')) {
		my @used_nskeys	= keys %{ $self->{used_ns} };
		if (@used_nskeys) {
			my $string	= '';
			foreach my $ns (sort @used_nskeys) {
				my $uri	= $ns{ $ns };
				$string	.= "\@prefix $ns: <$uri> .\n";
			}
			$string	.= "\n";
			$sink->prepend($string);
		}
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to Turtle, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $sink	= RDF::Trine::Serializer::StringSink->new();
	$self->serialize_iterator( $sink, $iter, seen => {}, level => 0, tab => "\t", @_, string => 1 );
	return $sink->string;
}

=item C<< serialize_node ( $node ) >>

Returns a string containing the Turtle serialization of C<< $node >>.

=cut

sub serialize_node {
	my $self	= shift;
	my $node	= shift;
	return $self->node_as_concise_string( $node );
}

sub _serialize_object_to_file {
	my $self	= shift;
	my $sink	= shift;
	my $subj	= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	my $indent	= $tab x $level;
	
	if (my $model = $args{model}) {
		if ($subj->isa('RDF::Trine::Node::Blank')) {
			if ($self->_check_valid_rdf_list( $subj, $model )) {
# 				warn "node is a valid rdf:List: " . $subj->as_string . "\n";
				return $self->_turtle_rdf_list( $sink, $subj, $model, $seen, $level, $tab, %args );
			} else {
				my $count	= $model->count_statements( undef, undef, $subj );
				my $rec		= $model->count_statements( $subj, undef, $subj );
				warn "count=$count, rec=$rec for node " . $subj->as_string if ($debug);
				if ($count == 1 and $rec == 0) {
					unless ($seen->{ $subj->as_string }++ or $seen->{ '  heads' }{ $subj->as_string }) {
						my $pat		= RDF::Trine::Pattern->new( RDF::Trine::Statement->new($subj, variable('p'), variable('o')) );
						my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(p ASC o ASC) ] );
						my $iter	= $stream->as_statements( qw(s p o) );
						my $last_pred;
						my $triple_count	= 0;
						$sink->emit("[");
						while (my $st = $iter->next) {
							my $pred	= $st->predicate;
							my $obj		= $st->object;
							
							# continue an existing subject
							if ($pred->equal( $last_pred )) {
								# continue an existing predicate
								$sink->emit(qq[, ]);
								$self->_serialize_object_to_file( $sink, $obj, $seen, $level, $tab, %args );
#								$self->_turtle( $fh, $obj, 2, $seen, $level, $tab, %args );
							} else {
								# start a new predicate
								if ($triple_count == 0) {
									$sink->emit(qq[\n${indent}${tab}${tab}]);
								} else {
									$sink->emit(qq[ ;\n${indent}$tab${tab}]);
								}
								$self->_turtle( $sink, $pred, 1, $seen, $level, $tab, %args );
								$sink->emit(' ');
								$self->_serialize_object_to_file( $sink, $obj, $seen, $level+1, $tab, %args );
							}
							
							$last_pred	= $pred;
							$triple_count++;
						}
						if ($triple_count) {
							$sink->emit("\n${indent}${tab}");
						}
						$sink->emit("]");
						return;
					}
				}
			}
		}
	}
	
	$self->_turtle( $sink, $subj, 2, $seen, $level, $tab, %args );
}

sub _statement_describes_list {
	my $self	= shift;
	my $model	= shift;
	my $st		= shift;
	my $subj	= $st->subject;
	my $pred	= $st->predicate;
	my $obj		= $st->object;
	if ($model->count_statements($subj, $rdf->first) and $model->count_statements($subj, $rdf->rest)) {
# 		warn $subj->as_string . " looks like a rdf:List element";
		if (my $head = $self->_node_belongs_to_valid_list( $model, $subj )) {
			return $head;
		}
	}
	
	return;
}

sub _node_belongs_to_valid_list {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	while ($model->count_statements( undef, $rdf->rest, $node )) {
		my $iter		= $model->get_statements( undef, $rdf->rest, $node );
		my $s			= $iter->next;
		my $ancestor	= $s->subject;
		unless (blessed($ancestor)) {
# 			warn "failed to get an expected rdf:List element ancestor";
			return 0;
		}
		($node)	= $ancestor;
# 		warn "stepping back to rdf:List element ancestor " . $node->as_string;
	}
	if ($self->_check_valid_rdf_list( $node, $model )) {
		return $node;
	} else {
		return;
	}
}

sub _check_valid_rdf_list {
	my $self	= shift;
	my $head	= shift;
	my $model	= shift;
# 	warn '--------------------------';
# 	warn "checking if node " . $head->as_string . " is a valid rdf:List\n";
	
	my $headrest	= $model->count_statements( undef, $rdf->rest, $head );
	if ($headrest) {
# 		warn "\tnode " . $head->as_string . " seems to be the middle of an rdf:List\n";
		return 0;
	}
	
	my %list_elements;
	my $node	= $head;
	until ($node->equal( $rdf->nil )) {
		$list_elements{ $node->as_string }++;
		
		unless ($node->isa('RDF::Trine::Node::Blank')) {
# 			warn "\tnode " . $node->as_string . " isn't a blank node\n";
			return 0;
		}
		
		my $first	= $model->count_statements( $node, $rdf->first );
		unless ($first == 1) {
# 			warn "\tnode " . $node->as_string . " has $first rdf:first links when 1 was expected\n";
			return 0;
		}
		
		my $rest	= $model->count_statements( $node, $rdf->rest );
		unless ($rest == 1) {
# 			warn "\tnode " . $node->as_string . " has $rest rdf:rest links when 1 was expected\n";
			return 0;
		}
		
		my $in		= $model->count_statements( undef, undef, $node );
		unless ($in < 2) {
# 			warn "\tnode " . $node->as_string . " has $in incoming links when 2 were expected\n";
			return 0;
		}
		
		if (not($head->equal( $node ))) {
			# It's OK for the head of a list to have any outgoing links (e.g. (1 2) ex:p "o"
			# but internal list elements should have only the expected links of rdf:first, 
			# rdf:rest, and optionally an rdf:type rdf:List
			my $out		= $model->count_statements( $node );
			unless ($out == 2 or $out == 3) {
# 				warn "\tnode " . $node->as_string . " has $out outgoing links when 2 or 3 were expected\n";
				return 0;
			}
			
			if ($out == 3) {
				my $type	= $model->count_statements( $node, $rdf->type, $rdf->List );
				unless ($type == 1) {
# 					warn "\tnode " . $node->as_string . " has more outgoing links than expected\n";
					return 0;
				}
			}
		}
		
		
		
		my @links	= $model->objects_for_predicate_list( $node, $rdf->first, $rdf->rest );
		foreach my $l (@links) {
			if ($list_elements{ $l->as_string }) {
				warn $node->as_string . " is repeated in the list" if ($debug);
				return 0;
			}
		}
		
		($node)	= $model->objects_for_predicate_list( $node, $rdf->rest );
		unless (blessed($node)) {
# 			warn "\tno valid rdf:rest object found";
			return 0;
		}
# 		warn "\tmoving on to rdf:rest object " . $node->as_string . "\n";
	}
	
# 	warn "\tlooks like a valid rdf:List\n";
	return 1;
}

sub _turtle_rdf_list {
	my $self	= shift;
	my $sink	= shift;
	my $head	= shift;
	my $model	= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	my $node	= $head;
	my $count	= 0;
	$sink->emit('(');
	until ($node->equal( $rdf->nil )) {
		if ($count) {
			$sink->emit(' ');
		}
		my ($value)	= $model->objects_for_predicate_list( $node, $rdf->first );
		$self->_serialize_object_to_file( $sink, $value, $seen, $level, $tab, %args );
		$seen->{ $node->as_string }++;
		($node)		= $model->objects_for_predicate_list( $node, $rdf->rest );
		$count++;
	}
	$sink->emit(')');
}

sub _node_concise_string {
	my $self	= shift;
	my $obj		= shift;
	if ($obj->is_literal and $obj->has_datatype) {
		my $dt	= $obj->literal_datatype;
		if ($dt =~ m<^http://www.w3.org/2001/XMLSchema#(integer|double|decimal)$> and $obj->is_canonical_lexical_form) {
			my $value	= $obj->literal_value;
			return $value;
		} else {
			my $dtr	= iri($dt);
			my $literal	= $obj->literal_value;
			my $qname;
			try {
				my ($ns,$local)	= $dtr->qname;
				if (blessed($self) and exists $self->{ns}{$ns}) {
					$qname	= join(':', $self->{ns}{$ns}, $local);
					$self->{used_ns}{ $self->{ns}{$ns} }++;
				}
			} catch RDF::Trine::Error with {};
			if ($qname) {
				my $escaped	= $obj->_unicode_escape( $literal );
				return qq["$escaped"^^$qname];
			}
		}
	} elsif ($obj->isa('RDF::Trine::Node::Resource')) {
		my $value;
		try {
			my ($ns,$local)	= $obj->qname;
			if (blessed($self) and exists $self->{ns}{$ns}) {
				$value	= join(':', $self->{ns}{$ns}, $local);
				$self->{used_ns}{ $self->{ns}{$ns} }++;
			}
		} catch RDF::Trine::Error with {} otherwise {};
		if ($value) {
			return $value;
		}
	}
	return;
}

=item C<< node_as_concise_string >>

Returns a string representation using common Turtle syntax shortcuts (e.g. for numeric literals).

=cut

sub node_as_concise_string {
	my $self	= shift;
	my $obj		= shift;
	my $str		= $self->_node_concise_string( $obj );
	if (defined($str)) {
		return $str;
	} else {
		return $obj->as_ntriples;
	}
}

sub _turtle {
	my $self	= shift;
	my $sink	= shift;
	my $obj		= shift;
	my $pos		= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	
	if ($obj->isa('RDF::Trine::Node::Resource') and $pos == 1 and $obj->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		$sink->emit('a');
		return;
	} elsif ($obj->isa('RDF::Trine::Node::Blank') and $pos == 0) {
		if (my $model = $args{ model }) {
			my $count	= $model->count_statements( undef, undef, $obj );
			my $rec		= $model->count_statements( $obj, undef, $obj );
			# XXX if $count == 1, then it would be better to ignore this triple for now, since it's a 'single-owner' bnode, and better serialized as a '[ ... ]' bnode in the object position as part of the 'owning' triple
			if ($count < 1 and $rec == 0) {
				$sink->emit('[]');
				return;
			}
		}
	} elsif (defined(my $str = $self->_node_concise_string( $obj ))) {
		$sink->emit($str);
		return;
	}
	
	$sink->emit($obj->as_ntriples);
	return;
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://www.w3.org/TeamSubmission/turtle/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
