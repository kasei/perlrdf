# RDF::Trine::Serializer::SPARQLJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::SPARQLJSON - SPARQL JSON Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::SPARQLJSON version 0.135

=head1 SYNOPSIS

 use RDF::Trine::Serializer::SPARQLJSON;
 my $serializer	= RDF::Trine::Serializer::SPARQLJSON->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::SPARQLJSON class provides an API for serializing RDF
variable bindings sets to the SPARQL JSON syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::SPARQLJSON;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use JSON 2.0;

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.135';
}
use RDF::Trine::Serializer -base => {
	serializer_names	=> [qw{sparqljson}],
	format_uris			=> ['http://www.w3.org/ns/formats/SPARQL_Results_JSON'],
	media_types			=> [qw{application/sparql-results+json}],
	content_classes		=> [qw(RDF::Trine::Model RDF::Trine::Iterator::Bindings)],
};

######################################################################

=item C<< new >>

Returns a new SPARQLJSON serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to N-Triples, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $file	= shift;
	my $model	= shift;
	my $max_result_size	= shift || 0;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $self->serialize_iterator_to_file( $file, $iter, $max_result_size );
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to SPARQL JSON, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $max_result_size	= shift || 0;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $self->serialize_iterator_to_string( $iter, $max_result_size );
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to N-Triples, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self			= shift;
	my $fh				= shift;
	my $iter			= shift;
	my $max_result_size	= shift || 0;
	my $width			= $iter->bindings_count;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $iter->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my $count	= 0;
	my @sorted	= $iter->sorted_by;
	my $order	= scalar(@sorted) ? JSON::true : JSON::false;
	my $dist	= $iter->_args->{distinct} ? JSON::true : JSON::false;
	
	my $data	= {
					head	=> { vars => \@variables },
					results	=> { ordered => $order, distinct => $dist },
				};
	my @bindings;
	while (!$iter->finished) {
		my %row;
		for (my $i = 0; $i < $width; $i++) {
			my $name		= $iter->binding_name($i);
			my $value		= $iter->binding_value($i);
			if (blessed($value)) {
				if (my ($k, $v) = format_node_json($value, $name)) {
					$row{ $k }		= $v;
				}
			}
		}
		
		push(@{ $data->{results}{bindings} }, \%row);
		last if ($max_result_size and ++$count >= $max_result_size);
	} continue { $iter->next_result }
	
	print {$fh} to_json( $data );
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to N-Triples, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $max_result_size	= shift || 0;
	my $string	= '';
	open( my $fh, '>', \$string );
	$self->serialize_iterator_to_file( $fh, $iter, $max_result_size );
	close($fh);
	return $string;
}

=begin private

=item C<format_node_json ( $node, $name )>

Returns a string representation of C<$node> for use in a JSON serialization.

=end private

=cut

sub format_node_json ($$) {
	my $node	= shift;
	my $name	= shift;
	my $node_label;
	
	if(!defined $node) {
		return;
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		$node_label	= $node->uri_value;
		return $name => { type => 'uri', value => $node_label };
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		$node_label	= $node->literal_value;
		return $name => { type => 'literal', value => $node_label };
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		$node_label	= $node->blank_identifier;
		return $name => { type => 'bnode', value => $node_label };
	} else {
		return;
	}
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-sparql-XMLres/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
