# RDF::Trine::Serializer::Turtle
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::Turtle - Turtle Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::Turtle version 0.113_02

=head1 SYNOPSIS

 use RDF::Trine::Serializer::Turtle;
 my $serializer	= RDF::Trine::Serializer::Turtle->new();

=head1 DESCRIPTION

...

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

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.113_02';
}

######################################################################

=item C<< new ( %namespaces ) >>

Returns a new Turtle serializer object.

=cut

sub new {
	my $class	= shift;
	my $ns		= shift || {};
	my $self = bless( { ns => { reverse %$ns } }, $class );
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
		my $subj	= $st->subject;
		my $pred	= $st->predicate;
		my $obj		= $st->object;
		next if ($seen->{ $subj->as_string });
		
		if ($subj->equal( $last_subj )) {
			# continue an existing subject
			if ($pred->equal( $last_pred )) {
				# continue an existing predicate
				print {$fh} qq[, ];
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level, $tab, %args );
			} else {
				# start a new predicate
				print {$fh} qq[ ;\n${indent}$tab];
				print {$fh} $self->_turtle( $pred, 1, %args ) . ' ';
				$self->_serialize_object_to_file( $fh, $obj, $seen, $level, $tab, %args );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				print {$fh} qq[ .\n${indent}];
			}
			$open_triple	= 1;
			print {$fh} $self->_turtle( $subj, 0, %args ) . ' ';
			print {$fh} $self->_turtle( $pred, 1, %args ) . ' ';
			$self->_serialize_object_to_file( $fh, $obj, $seen, $level, $tab, %args );
		}
		
		if (blessed($last_subj) and not($last_subj->equal($subj))) {
			$seen->{ $subj->as_string }++;
		}
		$last_subj	= $subj;
		$last_pred	= $pred;
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
			my $count	= $model->count_statements( undef, undef, $subj );
			if ($count == 1) {
				$seen->{ $subj->as_string }++;
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
						print {$fh} $self->_turtle( $obj, 2, %args );
					} else {
						# start a new predicate
						if ($triple_count == 0) {
							print {$fh} qq[\n${indent}${tab}${tab}];
						} else {
							print {$fh} qq[ ;\n${indent}$tab${tab}];
						}
						print {$fh} $self->_turtle( $pred, 1, %args ) . ' ';
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
	
	print {$fh} $self->_turtle( $subj, 2, %args );
}

sub _turtle {
	my $self	= shift;
	my $obj		= shift;
	my $pos		= shift;
	my %args	= @_;
	if ($obj->is_resource and $pos == 1 and $obj->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		return 'a';
	} elsif ($obj->is_blank and $pos == 0) {
		if (my $model = $args{ model }) {
			my $count	= $model->count_statements( undef, undef, $obj );
			if ($count < 2) {
				return '[]';
			}
		}
	} elsif ($obj->is_literal and $obj->has_datatype) {
		my $dt	= $obj->literal_datatype;
		if ($dt =~ m<^http://www.w3.org/2001/XMLSchema#(integer|double|decimal)$>) {
			my $type	= $1;
			my $value	= $obj->literal_value;
			if ($type eq 'integer' and $value =~ m/^[-+]?[0-9]+$/) {
				return $value;
			} elsif ($type eq 'double' and $value =~ m/^[-+]?([0-9]+[.][0-9]*[eE][-+]?[0-9]+|[.][0-9]+[eE][-+]?[0-9]+|[0-9]+[eE][-+]?[0-9]+)$/) {
				return $value;
			} elsif ($type eq 'decimal' and $value =~ m/^[-+]?([0-9]+[.][0-9]*|[.][0-9]+|[0-9]+)$/) {
				return $value;
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
			return $value;
		}
	}
	
	return $obj->as_ntriples;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
