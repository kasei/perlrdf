# RDF::Trine::Model::Dataset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model::Dataset - Model for SPARQL datasets

=head1 VERSION

This document describes RDF::Trine::Model::Dataset version 0.123

=head1 METHODS

=over 4

=cut

package RDF::Trine::Model::Dataset;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Model);
use Scalar::Util qw(blessed);

use RDF::Trine::Model;

our ($VERSION);
BEGIN {
	$VERSION	= '0.123';
}

################################################################################

=item C<< new ( $model ) >>

Returns a new dataset-model over the supplied model.

=cut

sub new {
	my $class	= shift;
	my $model	= shift;
	my $self	= bless({ model => $model, stack => [] }, $class);
}

=item C<< push_default_graphs ( @graphs ) >>

=cut

sub push_default_graphs {
	my $self	= shift;
	my @graphs	= @_;
	unshift(@{ $self->{ stack } }, {});
	foreach my $graph (@graphs) {
		my $name	= blessed($graph) ? $graph->uri_value : $graph;
		$graph		= blessed($graph) ? $graph : RDF::Trine::Node::Resource->new( $graph );
		$self->{stack}[0]{$name}	= $graph;
	}
	return 1;
}

=item C<< pop_default_graphs >>

=cut

sub pop_default_graphs {
	my $self	= shift;
	shift(@{ $self->{ stack } });
	return 1;
}

=item C<< temporary_model >>
 
Returns a new temporary (non-persistent) model.
 
=cut
 
sub temporary_model {
	my $class	= shift;
	my $model	= RDF::Trine::Model->temporary_model;
	return $class->new( $model );
}

=item C<< add_hashref ( $hashref [, $context] ) >>

Add triples represented in an RDF/JSON-like manner to the model.

=cut

sub add_hashref {
	my $self	= shift;
	return $self->model->add_hashref( @_ );
}

=item C<< size >>

Returns the number of statements in the model.

=cut

sub size {
	my $self	= shift;
	return $self->model->size;
}

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	return $self->model->count_statements( @_ ) unless (scalar(@{ $self->{stack} }));
	my $use_quad	= (scalar(@_) >= 4);
	if ($use_quad) {
# 		warn "counting quads with dataset";
		my $quad	= $_[3];
		if (blessed($quad) and $quad->isa('RDF::Trine::Node::Nil')) {
# 			warn "- default graph query";
# 			warn "- " . join(', ', keys %{ $self->{stack}[0] });
			my $count	= 0;
			foreach my $g (values %{ $self->{stack}[0] }) {
				$count	+= $self->model->count_statements( @_[0..2], $g );
# 				warn "$count statments in graph " . $g->uri_value;
			}
			return $count;
		} else {
# 			warn "- NOT a default graph query";
			return $self->model->count_statements( @_ );
		}
	} else {
		return $self->model->count_statements( @_ );
	}
}

=item C<< add_statement ( $statement [, $context] ) >>
 
Adds the specified C<< $statement >> to the rdf store.
 
=cut
 
sub add_statement {
	my $self	= shift;
	return $self->model->add_statement( @_ );
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<< $statement >> from the rdf store.

=cut

sub remove_statement {
	my $self	= shift;
	return $self->model->remove_statement( @_ );
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context] ) >>

Removes all statements matching the supplied C<< $statement >> pattern from the rdf store.

=cut

sub remove_statements {
	my $self	= shift;
	return $self->model->remove_statements( @_ );
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
	my $self		= shift;
	return $self->model->get_statements( @_ ) unless (scalar(@{ $self->{stack} }));
	my $bound		= 0;
	my $use_quad	= (scalar(@_) >= 4);
	if ($use_quad) {
		my $quad	= $_[3];
		if (blessed($quad) and not($quad->isa('RDF::Trine::Node::Variable')) and not($quad->isa('RDF::Trine::Node::Nil'))) {
			return $self->model->get_statements( @_ );
		} else {
			my @iters;
			foreach my $g (values %{ $self->{stack}[0] }) {
				push(@iters, $self->model->get_statements( @_[0..2], $g ));
			}
			if (not(defined($quad)) or $quad->isa('RDF::Trine::Node::Variable')) {
				my $graphs	= $self->get_contexts;
				while (my $g = $graphs->next) {
					next if ($g->isa('RDF::Trine::Node::Nil'));
					push(@iters, $self->model->get_statements( @_[0..2], $g ));
				}
			}
			my %seen;
			my $code	= sub {
				while (1) {
					return unless scalar(@iters);
					my $st	= $iters[0]->next;
					if ($st) {
						if ($seen{ $st->as_string }++) {
							next;
						}
						return $st;
					} else {
						shift(@iters);
					}
				}
			};
			my $iter	= RDF::Trine::Iterator::Graph->new( $code );
		}
	} else {
		return $self->model->get_statements( @_ );
	}
}

sub get_pattern {
	my $self	= shift;
	return $self->model->get_pattern( @_ ) unless (scalar(@{ $self->{stack} }));
	my $use_quad	= (scalar(@_) >= 4);
	if ($use_quad) {
		my $quad	= $_[3];
		if (blessed($quad) and not($quad->isa('RDF::Trine::Node::Variable')) and not($quad->isa('RDF::Trine::Node::Nil'))) {
			return $self->model->get_pattern( @_ );
		} else {
			return $self->SUPER::get_pattern( @_ );
		}
	} else {
		return $self->model->get_pattern( @_ );
	}
}

sub get_contexts {
	my $self	= shift;
	return $self->model->get_contexts( @_ );
}

sub as_stream {
	my $self	= shift;
	return $self->model->as_stream( @_ );
}

sub as_hashref {
	my $self	= shift;
	return $self->model->as_hashref( @_ );
}

sub subjects {
	my $self	= shift;
	return $self->model->subjects( @_ );
}
sub predicates {
	my $self	= shift;
	return $self->model->predicates( @_ );
}
sub objects {
	my $self	= shift;
	return $self->model->objects( @_ );
}
sub objects_for_predicate_list {
	my $self	= shift;
	return $self->model->objects_for_predicate_list( @_ );
}
sub bounded_description {
	my $self	= shift;
	return $self->model->bounded_description( @_ );
}

sub model {
	my $self	= shift;
	return $self->{model};
}

sub _store {
	my $self	= shift;
	return;
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
