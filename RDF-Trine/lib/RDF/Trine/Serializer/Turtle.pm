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
				print {$fh} $obj->as_ntriples;
			} else {
				# start a new predicate
				print {$fh} qq[ ;\n\t];
				print {$fh} join( ' ', $pred->as_ntriples, $obj->as_ntriples );
			}
		} else {
			# start a new subject
			if ($open_triple) {
				print {$fh} qq[ .\n];
			}
			$open_triple	= 1;
			print {$fh} join( ' ',
				$subj->as_ntriples,
				$pred->as_ntriples,
				$obj->as_ntriples,
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
