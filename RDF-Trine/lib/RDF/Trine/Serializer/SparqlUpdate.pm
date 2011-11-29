# RDF::Trine::Serializer::SparqlUpdate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::SparqlUpdate - SPARQL/U serialization of triples

=head1 DESCRIPTION

TODO

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut
package RDF::Trine::Serializer::SparqlUpdate;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Serializer::NTriples);

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use SUPER;

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.001';
    $RDF::Trine::Serializer::serializer_names{ 'sparqlu' }	= __PACKAGE__;
    $RDF::Trine::Serializer::format_uris{ 'http://www.w3.org/Submission/SPARQL-Update/' }	= __PACKAGE__;
    foreach my $type (qw(application/sparql-update)) {
        $RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
    }
}

######################################################################

=item C<< new >>

Returns a new N-Triples serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
    # $args{} //= 'INSERT DATA';
    # $args{graph} = undef;
    # $args{swap_clauses} //= 'DELETE {';
    $args{insert_clause} //= '';
    $args{insert_start} //= 'INSERT {';
    $args{insert_end} //= '}';

    # $args{delete_model} //= undef;
    $args{delete_clause} //= '';
    $args{delete_start} //= 'DELETE {';
    $args{delete_end} //= '}';

    $args{where_clause} //= '';
	my $self = bless( {%args}, $class);
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
    $self->{insert_model} = $model;
    print {$file} $self->_serialize_model_to_modify_clause;
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to N-Triples, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
    $self->{insert_model} = $model;
    return $self->_serialize_model_to_modify_clause;
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to N-Triples, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $file	= shift;
	my $iter	= shift;
    $self->{insert_iter} = $iter;
    print {$file} $self->_serialize_model_to_modify_clause;
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to N-Triples, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
    $self->{insert_iter} = $iter;
    return $self->_serialize_model_to_modify_clause;
}

sub _serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	return '' if ($seen->{ $node->sse }++);
	my $iter	= $model->get_statements( $node, undef, undef );
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->statement_as_string( $st );
		if ($nodes[2]->isa('RDF::Trine::Node::Blank')) {
			$string	.= $self->_serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	return $string;
}

=item C<< statement_as_string ( $st ) >>

Returns a string with the supplied RDF::Trine::Statement object serialized as
N-Triples, ending in a DOT and newline.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	my $to_return .= join(' ', map { $_->as_ntriples } @nodes[0..2]) . " .\n";
    return $to_return;
}

=item C<< serialize_node ( $node ) >>

Returns a string containing the N-Triples serialization of C<< $node >>.

=cut

sub serialize_node {
	my $self	= shift;
	my $node	= shift;
	return $node->as_ntriples;
}

sub _serialize_model_to_modify_clause {
    my $self = shift;
    my $insert_model = shift;
    # my $insert_clause = shift;
    my $string = '';

    if ($self->{graph}) {
        $string .= 'WITH ';
        $string .= sprintf '<%s>', $self->{graph};
    }
    $string .= "\n";

    if ($self->{delete_model}) {
        $self->{delete_clause} = RDF::Trine::Serializer::NTriples->new->serialize_model_to_string( $self->{delete_model} );
    }
    elsif ($self->{delete_iter}) {
        $self->{delete_clause} = RDF::Trine::Serializer::NTriples->new->serialize_iterator_to_string( $self->{delete_iter} );
    }
    # warn Dumper $self->{delete_clause};
    if ($self->{delete_clause}) {
        $string .= $self->{delete_start};
        $string .= $self->{delete_clause};
        $string .= $self->{delete_end};
        $string .= "\n";
    }

    if ($self->{insert_model}) {
        $self->{insert_clause} = RDF::Trine::Serializer::NTriples->new->serialize_model_to_string( $self->{insert_model} );
    }
    elsif ($self->{insert_iter}) {
        $self->{insert_clause} = RDF::Trine::Serializer::NTriples->new->serialize_iterator_to_string( $self->{insert_iter} );
    }
    if ($self->{insert_clause}) {
        $string .= $self->{insert_start};
        $string .= $self->{insert_clause};
        $string .= $self->{insert_end};
        $string .= "\n";
    }


    # if ($self->{where_clause}) {
    $string .= 'WHERE {';
    $string .= $self->{where_clause};
    $string .= '}';
    # }
    $string .= "\n";

    # TODO reset options to default so changes become atomic
    # $self = __PACKAGE__->new;


    return $string;
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-testcases/#ntriples>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
