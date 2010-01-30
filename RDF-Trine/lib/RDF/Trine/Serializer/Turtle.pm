# RDF::Trine::Serializer::Turtle
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::Turtle - Turtle Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::Turtle version 0.115

=head1 SYNOPSIS

 use RDF::Trine::Serializer::Turtle;
 my $serializer	= RDF::Trine::Serializer::Turtle->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::Turtle class provides an API for serializing RDF
graphs to the Turtle syntax. XSD numeric types are serialized as bare literals,
and where possible the more concise syntax is used for rdf:Lists.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Serializer::Turtle;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);
use RDF::Trine::Namespace qw(rdf);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '0.115';
}

######################################################################

=item C<< new ( %namespaces ) >>

Returns a new Turtle serializer object.

=cut

sub new {
	my $class	= shift;
	my $ns		= shift || {};
	my $self = bless( {
		ns			=> { reverse %$ns },
	}, $class );
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to RDF/XML, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $model	= shift;
	my $iter	= $model->as_stream;
	
	$self->serialize_iterator_to_file( $fh, $iter, {}, 0, "\t", model => $model );
	return 1;
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to RDF/XML, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $string	= '';
	open( my $fh, '>', \$string );
	$self->serialize_model_to_file( $fh, $model, {}, 0, "\t", model => $model );
	close($fh);
	return $string;
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to RDF/XML, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $iter	= shift;
	my $seen	= shift || {};
	my $level	= scalar(@_) ? shift : 0;
	my $tab		= scalar(@_) ? shift : "\t";
	my %args	= @_;
	my $indent	= $tab x $level;
	
	my %ns		= reverse %{ $self->{ns} };
	my @nskeys	= sort keys %ns;
	if (@nskeys) {
		foreach my $ns (@nskeys) {
			my $uri	= $ns{ $ns };
			print {$fh} "\@prefix $ns: <$uri> .\n";
		}
		print {$fh} "\n";
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
		
# 		my $valid_list_head	= 0;
# 		my $valid_list		= 0;
		if (my $model = $args{model}) {
			if (my $head = $self->_statement_describes_list($model, $st)) {
# 				$valid_list	= 1;
				warn "found a rdf:List head " . $head->as_string . " for the subject in statement " . $st->as_string if ($debug);
				if ($model->count_statements(undef, undef, $head)) {
					# the rdf:List appears as the object of a statement, and so
					# will be serialized whenever we get to serializing that
					# statement
					warn "next" if ($debug);
					next;
				}
# 				
# 				if ($head->equal( $subj )) {
# 					# the rdf:List doesn't appear as the object of any statement,
# 					# so it needs to be serialized here.
# 					warn $head->as_string . " is a valid rdf:List head" if ($debug);
# 					$valid_list_head	= 1;
# 				} else {
# 					warn "next" if ($debug);
# 					next;
# 				}
			}
		}
		
		if ($seen->{ $subj->as_string }) {
# 			if ($valid_list) {
# 				if ($pred->equal($rdf->first) or $pred->equal($rdf->rest)) {
# 					warn "next" if ($debug);
# 					next;
# 				} else {
# 					# don't skip these statements, because while we've "seen" the list head already
# 					# that only means we've serialized the expected list part of it (e.g. "(1 2)")
# 					# not any other links hanging off of the list head (e.g. "(1 2) ex:p <object>").
# 					warn "don't skip" if ($debug);
# 				}
# 			} else {
				warn "next" if ($debug);
				next;
# 			}
		}
		
		if ($subj->equal( $last_subj )) {
			# continue an existing subject
			if ($pred->equal( $last_pred )) {
				# continue an existing predicate
				print {$fh} qq[, ];
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level, $tab, %args );
			} else {
				# start a new predicate
# 				if ($valid_list_head) {
# 					print {$fh} ' ';
# 				} else {
					print {$fh} qq[ ;\n${indent}$tab];
# 				}
				$self->_turtle( $fh, $pred, 1, $seen, $level, $tab, %args );
				print {$fh} ' ';
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level, $tab, %args );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				print {$fh} qq[ .\n${indent}];
			}
			$open_triple	= 1;
# 			if ($valid_list_head) {
# 				$self->_turtle_rdf_list( $fh, $subj, $args{model}, $seen, $level, $tab, %args );
# 				$seen->{ $subj->as_string }++;
# 			} else {
				$self->_turtle( $fh, $subj, 0, $seen, $level, $tab, %args );
# 			}
			
			warn '-> ' . $pred->as_string if ($debug);
# 			if (not($valid_list_head) or ($valid_list_head and not($pred->equal($rdf->first)) and not($pred->equal($rdf->rest)))) {
				print {$fh} ' ';
				$self->_turtle( $fh, $pred, 1, $seen, $level, $tab, %args );
				print {$fh} ' ';
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level, $tab, %args );
# 			}
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
		print {$fh} qq[ .\n];
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to RDF/XML, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $string	= '';
	open( my $fh, '>', \$string );
	$self->serialize_iterator_to_file( $fh, $iter, {}, 0, "\t" );
	close($fh);
	return $string;
}

sub _serialize_object_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $subj	= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	my $indent	= $tab x $level;
	
	if (my $model = $args{model}) {
		if ($subj->is_blank) {
			if ($self->_check_valid_rdf_list( $subj, $model )) {
# 				warn "node is a valid rdf:List: " . $subj->as_string . "\n";
				return $self->_turtle_rdf_list( $fh, $subj, $model, $seen, $level, $tab, %args );
			} else {
				my $count	= $model->count_statements( undef, undef, $subj );
				my $rec		= $model->count_statements( $subj, undef, $subj );
				if ($count == 1 and $rec == 0) {
					unless ($seen->{ $subj->as_string }++) {
						my $iter	= $model->get_statements( $subj, undef, undef );
						my $last_pred;
						my $triple_count	= 0;
						print {$fh} "[";
						while (my $st = $iter->next) {
							my $pred	= $st->predicate;
							my $obj		= $st->object;
							
							# continue an existing subject
							if ($pred->equal( $last_pred )) {
								# continue an existing predicate
								print {$fh} qq[, ];
								$self->_turtle( $fh, $obj, 2, $seen, $level, $tab, %args );
							} else {
								# start a new predicate
								if ($triple_count == 0) {
									print {$fh} qq[\n${indent}${tab}${tab}];
								} else {
									print {$fh} qq[ ;\n${indent}$tab${tab}];
								}
								$self->_turtle( $fh, $pred, 1, $seen, $level, $tab, %args );
								print {$fh} ' ';
								$self->_serialize_object_to_file( $fh, $obj, $seen, $level+1, $tab, %args );
							}
							
							$last_pred	= $pred;
							$triple_count++;
						}
						if ($triple_count) {
							print {$fh} "\n${indent}${tab}";
						}
						print {$fh} "]";
						return;
					}
				}
			}
		}
	}
	
	$self->_turtle( $fh, $subj, 2, $seen, $level, $tab, %args );
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
		
		unless ($node->is_blank) {
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
	my $fh		= shift;
	my $head	= shift;
	my $model	= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	my $node	= $head;
	my $count	= 0;
	print {$fh} '(';
	until ($node->equal( $rdf->nil )) {
		if ($count) {
			print {$fh} ' ';
		}
		my ($value)	= $model->objects_for_predicate_list( $node, $rdf->first );
		$self->_serialize_object_to_file( $fh, $value, $seen, $level, $tab, %args );
		$seen->{ $node->as_string }++;
		($node)		= $model->objects_for_predicate_list( $node, $rdf->rest );
		$count++;
	}
	print {$fh} ')';
}

sub _turtle {
	my $self	= shift;
	my $fh		= shift;
	my $obj		= shift;
	my $pos		= shift;
	my $seen	= shift;
	my $level	= shift;
	my $tab		= shift;
	my %args	= @_;
	
	if ($obj->is_resource and $pos == 1 and $obj->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		print {$fh} 'a';
		return;
	} elsif ($obj->is_blank and $pos == 0) {
		if (my $model = $args{ model }) {
			my $count	= $model->count_statements( undef, undef, $obj );
			my $rec		= $model->count_statements( $obj, undef, $obj );
			if ($count < 2 and $rec == 0) {
				print {$fh} '[]';
				return;
			}
		}
	} elsif ($obj->is_literal and $obj->has_datatype) {
		my $dt	= $obj->literal_datatype;
		if ($dt =~ m<^http://www.w3.org/2001/XMLSchema#(integer|double|decimal)$>) {
			my $type	= $1;
			my $value	= $obj->literal_value;
			if ($type eq 'integer' and $value =~ m/^[-+]?[0-9]+$/) {
				print {$fh} $value;
				return;
			} elsif ($type eq 'double' and $value =~ m/^[-+]?([0-9]+[.][0-9]*[eE][-+]?[0-9]+|[.][0-9]+[eE][-+]?[0-9]+|[0-9]+[eE][-+]?[0-9]+)$/) {
				print {$fh} $value;
				return;
			} elsif ($type eq 'decimal' and $value =~ m/^[-+]?([0-9]+[.][0-9]*|[.][0-9]+|[0-9]+)$/) {
				print {$fh} $value;
				return;
			}
		}
	} elsif ($obj->is_resource) {
		my $value;
		try {
			my ($ns,$local)	= $obj->qname;
			if (exists $self->{ns}{$ns}) {
				$value	= join(':', $self->{ns}{$ns}, $local);
			}
		} catch RDF::Trine::Error with {};
		if ($value) {
			print {$fh} $value;
			return;
		}
	}
	
	print {$fh} $obj->as_ntriples;
	return;
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www.w3.org/TeamSubmission/turtle/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
