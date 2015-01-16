# RDF::Trine::Model::Dataset
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Model::Dataset - Model for SPARQL datasets

=head1 VERSION

This document describes RDF::Trine::Model::Dataset version 1.012

=head1 STATUS

This module's API and functionality should be considered unstable.
In the future, this module may change in backwards-incompatible ways,
or be removed entirely. If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Model> class.

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
	$VERSION	= '1.012';
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

=item C<< push_dataset ( default => \@graphs, named => \@graphs ) >>

Creates a new dataset view over the underlying model.

=cut

sub push_dataset {
	my $self	= shift;
	my %dataset	= @_;
	
	my @dgraphs	= @{ $dataset{ default } || [] };
	unshift(@{ $self->{ stack } }, { default => {}, named => {} });
	foreach my $graph (@dgraphs) {
		my $name	= blessed($graph) ? $graph->uri_value : $graph;
		$graph		= blessed($graph) ? $graph : RDF::Trine::Node::Resource->new( $graph );
		$self->{stack}[0]{default}{$name}	= $graph;
	}
	
	my @ngraphs	= @{ $dataset{ named } || [] };
	foreach my $graph (@ngraphs) {
		my $name	= blessed($graph) ? $graph->uri_value : $graph;
		$graph		= blessed($graph) ? $graph : RDF::Trine::Node::Resource->new( $graph );
		$self->{stack}[0]{named}{$name}	= $graph;
	}
	
	return 1;
}

=item C<< pop_dataset >>

Removes the last pushed dataset view.

=cut

sub pop_dataset {
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
	return $self->count_statements( undef, undef, undef, undef );
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
	return $self->model->count_statements( @_ ) unless (scalar(@{ $self->{stack} }));
	my $use_quad	= (scalar(@_) >= 4);
	if ($use_quad) {
# 		warn "counting quads with dataset";
		my $quad	= $_[3];
		if (blessed($quad) and $quad->isa('RDF::Trine::Node::Nil')) {
# 			warn "- default graph query";
# 			warn "- " . join(', ', keys %{ $self->{stack}[0] });
			my $count	= 0;
			foreach my $g (values %{ $self->{stack}[0]{default} }) {
				$count	+= $self->model->count_statements( @_[0..2], $g );
# 				warn "$count statments in graph " . $g->uri_value;
			}
			return $count;
		} elsif (not(defined($quad)) or (blessed($quad) and $quad->isa('RDF::Trine::Node::Variable'))) {
			my $iter	= $self->get_contexts;
			my $count	= 0;
			while (my $g = $iter->next) {
				$count	+= $self->model->count_statements( @_[0..2], $g );
			}
			return $count;
		} else {
			my $name	= blessed($quad) ? $quad->uri_value : $quad;
			if ($self->{stack}[0]{named}{ $name }) {
				return $self->model->count_statements( @_[0..2], $quad );
			} else {
				return 0;
			}
		}
	} else {
		my %seen;
		my $count	= 0;
		my $iter	= $self->get_statements( @_[0..2], undef );
		while (my $st = $iter->next) {
			warn 'counting triples in dataset: ' . $st->as_string;
			$count++ unless ($seen{ join(' ', map { $_->as_string } (map { $st->$_() } qw(subject predicate object)) ) }++);
		}
		return $count;
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
	my $nil			= RDF::Trine::Node::Nil->new();
	if ($use_quad) {
		my $quad	= $_[3];
		if (blessed($quad) and not($quad->isa('RDF::Trine::Node::Variable')) and not($quad->isa('RDF::Trine::Node::Nil'))) {
			if (exists($self->{stack}[0]{named}{$quad->uri_value})) {
				return $self->model->get_statements( @_ );
			} else {
				return RDF::Trine::Iterator::Graph->new([]);
			}
		} else {
			my @iters;
			foreach my $g (values %{ $self->{stack}[0]{default} }) {
				my $iter	= $self->model->get_statements( @_[0..2], $g );
				my $code	= sub {
					my $st	= $iter->next;
					return unless $st;
					my @nodes	= $st->nodes;
					$nodes[3]	= $nil;
					my $quad	= RDF::Trine::Statement::Quad->new( @nodes );
					return $quad;
				};
				push(@iters, RDF::Trine::Iterator::Graph->new( $code ));
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
			return $iter;
		}
	} else {
		my %seen;
		my @iters;
		my $iter	= $self->get_statements( @_[0..2], $nil );
		push(@iters, $iter);
		my $giter	= $self->get_contexts;
		while (my $g = $giter->next) {
			my $iter	= $self->get_statements( @_[0..2], $g );
			push(@iters, $iter);
		}
		
		my $code	= sub {
			while (1) {
				return unless scalar(@iters);
				my $st	= $iters[0]->next;
				if ($st) {
					my @nodes	= (map { $st->$_() } qw(subject predicate object));
					next if ($seen{ join(' ', map { $_->as_string } @nodes ) }++);
					return RDF::Trine::Statement->new( @nodes );
				} else {
					shift(@iters);
				}
			}
		};
		return RDF::Trine::Iterator::Graph->new( $code );
	}
}

=item C<< get_pattern ( $bgp [, $context] [, %args ] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

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

=item C<< get_sparql ( $sparql ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_sparql {
	my $self	= shift;
	return $self->model->get_sparql( @_ ) unless (scalar(@{ $self->{stack} }));
	throw RDF::Trine::Error::UnimplementedError -text => "Cannot execute SPARQL queries against a complex dataset model";
}

=item C<< get_graphs >>

=item C<< get_contexts >>

Returns an iterator containing the nodes representing the named graphs in the
model.

=cut

sub get_contexts {
	my $self	= shift;
	return $self->model->get_contexts unless (scalar(@{ $self->{stack} }));
	my @nodes	= values %{ $self->{stack}[0]{named} };
	if (wantarray) {
		return @nodes;
	} else {
		return RDF::Trine::Iterator->new( \@nodes );
	}
}
*get_graphs = \&get_contexts;

=item C<< model >>

Returns the underlying model object.

=cut

sub model {
	my $self	= shift;
	return $self->{model};
}

sub _store {
	my $self	= shift;
	return $self->model->_store;
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
