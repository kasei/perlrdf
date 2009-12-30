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
use Scalar::Util qw(blessed);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.113_02';
}

######################################################################

=item C<< new >>

Returns a new 

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( {}, $class);
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
	
	$self->serialize_iterator_to_file( $fh, $iter );
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
	$self->serialize_model_to_file( $fh, $model );
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
	
	my $last_subj;
	my $last_pred;
	
	my $open_triple	= 0;
	while (my $st = $iter->next) {
		my $subj	= $st->subject;
		my $pred	= $st->predicate;
		my $obj		= $st->object;
		if ($subj->equal( $last_subj )) {
			# continue an existing subject
			if ($pred->equal( $last_pred )) {
				# continue an existing predicate
				print {$fh} qq[, ];
				print {$fh} $self->_turtle( $obj, 2 );
			} else {
				# start a new predicate
				print {$fh} qq[ ;\n\t];
				print {$fh} join( ' ', $self->_turtle( $pred, 1 ), $self->_turtle( $obj, 2 ) );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				print {$fh} qq[ .\n];
			}
			$open_triple	= 1;
			print {$fh} join( ' ',
				$self->_turtle( $subj, 0 ),
				$self->_turtle( $pred, 1 ),
				$self->_turtle( $obj, 2 ),
			);
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
	$self->serialize_iterator_to_file( $fh, $iter );
	close($fh);
	return $string;
}

sub _turtle {
	my $self	= shift;
	my $obj		= shift;
	my $pos		= shift;
	if ($obj->is_resource and $pos == 1 and $obj->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
		return 'a';
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
