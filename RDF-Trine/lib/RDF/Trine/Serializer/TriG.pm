# RDF::Trine::Serializer::TriG
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::TriG - TriG Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::TriG version 0.115

=head1 SYNOPSIS

 use RDF::Trine::Serializer::TriG;
 my $serializer	= RDF::Trine::Serializer::TriG->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::TriG class provides an API for serializing RDF
graphs to the TriG syntax. XSD numeric types are serialized as bare literals,
and where possible the more concise syntax is used for rdf:Lists.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Serializer::TriG;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer::Turtle);

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);

use RDF::Trine qw(variable);
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

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to TriG, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $model	= shift;
	
	my $st		= RDF::Trine::Statement::Quad->new( map { variable($_) } qw(s p o g) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $stream	= $model->get_pattern( $pat, undef, orderby => [ qw(g ASC s ASC p ASC o ASC) ] );
	my $iter	= $stream->as_statements( qw(s p o) );
	
	warn '*********************************';
#	$self->_print_namespaces( $fh );
	$self->serialize_iterator_to_file( $fh, $iter, {}, 0, "\t", model => $model, namespaces => 0 );
	return 1;
}

sub _print_namespaces {
	my $self	= shift;
	my $fh		= shift;
	my %ns		= reverse %{ $self->{ns} };
	my @nskeys	= sort keys %ns;
	if (@nskeys) {
		foreach my $ns (@nskeys) {
			my $uri	= $ns{ $ns };
			print {$fh} "\@prefix $ns: <$uri> .\n";
		}
		print {$fh} "\n";
	}
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to TriG, printing the results to the supplied
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
	
	my $print_ns	= 1;
	if (exists $args{ namespaces }) {
		$print_ns	= $args{ namespaces };
	}
	if ($print_ns) {
		$self->_print_namespaces( $fh );
	}
	
	my $last_graph;
	my $last_subj;
	my $last_pred;
	
	my $open_triple	= 0;
	while (my $st = $iter->next) {
# 		warn "------------------\n";
# 		warn $st->as_string . "\n";
		my $subj	= $st->subject;
		my $pred	= $st->predicate;
		my $obj		= $st->object;
		my $graph	= ($st->type eq 'TRIPLE') ? RDF::Trine::Node::Nil->new : $st->context;
		
		if (not(defined($last_graph))) {
			print {$fh} "${indent}{\n${indent}$tab";
		} elsif (not($graph->equal($last_graph))) {
			if ($open_triple) {
				print {$fh} qq[ .\n];
			}
			$open_triple	= 0;
			print {$fh} "${indent}}\n\n{\n${indent}$tab";
			undef $last_subj;
			undef $last_pred;
		}
		
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
			}
		}
		
		if ($seen->{ $subj->as_string }) {
			warn "next" if ($debug);
			next;
		}
		
		if ($subj->equal( $last_subj )) {
			# continue an existing subject
			if ($pred->equal( $last_pred )) {
				# continue an existing predicate
				print {$fh} qq[, ];
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level+1, $tab, %args );
			} else {
				# start a new predicate
				print {$fh} qq[ ;\n${indent}$tab$tab];
				$self->_turtle( $fh, $pred, 1, $seen, $level+1, $tab, %args );
				print {$fh} ' ';
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level+1, $tab, %args );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				print {$fh} qq[ .\n${indent}$tab];
			}
			$open_triple	= 1;
			$self->_turtle( $fh, $subj, 0, $seen, $level+1, $tab, %args );
			
			warn '-> ' . $pred->as_string if ($debug);
			print {$fh} ' ';
			$self->_turtle( $fh, $pred, 1, $seen, $level+1, $tab, %args );
			print {$fh} ' ';
			$self->_serialize_object_to_file( $fh, $obj, $seen, $level+1, $tab, %args );
		}
	} continue {
		if (blessed($last_subj) and not($last_subj->equal($st->subject))) {
# 			warn "marking " . $st->subject->as_string . " as seen";
			$seen->{ $last_subj->as_string }++;
		}
# 		warn "setting last subject to " . $st->subject->as_string;
		$last_subj	= $st->subject;
		$last_pred	= $st->predicate;
		$last_graph	= ($st->type eq 'TRIPLE') ? RDF::Trine::Node::Nil->new : $st->context;
	}
	
	if ($open_triple) {
		print {$fh} qq[ .\n];
	}
	
	if ($last_graph) {
		print {$fh} "${indent}}\n";
	}
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www4.wiwiss.fu-berlin.de/bizer/TriG/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
