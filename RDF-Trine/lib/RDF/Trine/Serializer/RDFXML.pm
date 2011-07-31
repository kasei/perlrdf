# RDF::Trine::Serializer::RDFXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::RDFXML - RDF/XML Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::RDFXML version 0.135

=head1 SYNOPSIS

 use RDF::Trine::Serializer::RDFXML;
 my $serializer	= RDF::Trine::Serializer::RDFXML->new( namespaces => { ex => 'http://example/' } );
 print $serializer->serialize_model_to_string($model);

=head1 DESCRIPTION

The RDF::Trine::Serializer::Turtle class provides an API for serializing RDF
graphs to the RDF/XML syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::RDFXML;

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
	$VERSION	= '0.135';
	$RDF::Trine::Serializer::serializer_names{ 'rdfxml' }	= __PACKAGE__;
	$RDF::Trine::Serializer::format_uris{ 'http://www.w3.org/ns/formats/RDF_XML' }	= __PACKAGE__;
	foreach my $type (qw(application/rdf+xml)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new ( namespaces => \%namespaces, base_uri => $baseuri ) >>

Returns a new RDF/XML serializer object.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $self = bless( { namespaces => { 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' => 'rdf' } }, $class);
	if (my $ns = $args{namespaces}) {
		my %ns		= %{ $ns };
		my %nsmap;
		while (my ($ns, $uri) = each(%ns)) {
			for (1..2) {
				$uri	= $uri->uri_value if (blessed($uri));
			}
			$nsmap{ $uri }	= $ns;
		}
		@{ $self->{namespaces} }{ keys %nsmap }	= values %nsmap;
	}
	if ($args{base}) {
 	        $self->{base_uri} = $args{base};
        }
	if ($args{base_uri}) {
 	        $self->{base_uri} = $args{base_uri};
        }
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

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to RDF/XML, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $fh		= shift;
	my $iter	= shift;
	
	my $ns		= $self->_top_xmlns();
	my $base_uri        = '';
	if ($self->{base_uri}) {
	  $base_uri = "xml:base=\"$self->{base_uri}\" ";
	}
	print {$fh} qq[<?xml version="1.0" encoding="utf-8"?>\n<rdf:RDF $base_uri$ns>\n];
	
	my $st			= $iter->next;
	my @statements;
	push(@statements, $st) if blessed($st);
	while (@statements) {
		my $st	= shift(@statements);
		my @samesubj;
		push(@samesubj, $st);
		my $subj	= $st->subject;
		while (my $row = $iter->next) {
			if ($row->subject->equal( $subj )) {
				push(@samesubj, $row);
			} else {
				push(@statements, $row);
				last;
			}
		}
		
		print {$fh} $self->_statements_same_subject_as_string( @samesubj );
	}
	
	print {$fh} qq[</rdf:RDF>\n];
}

sub _statements_same_subject_as_string {
	my $self		= shift;
	my @statements	= @_;
	my $s			= $statements[0]->subject;
	
	my $id;
	if ($s->isa('RDF::Trine::Node::Blank')) {
		my $b	= $s->blank_identifier;
		$id	= qq[rdf:nodeID="$b"];
	} else {
		my $i	= $s->uri_value;
		for ($i) {
			s/&/&amp;/g;
			s/</&lt;/g;
			s/"/&quot;/g;
		}
		$id	= qq[rdf:about="$i"];
	}
	
	my $counter	= 1;
	my %namespaces	= %{ $self->{namespaces} };
	my $string	= '';
	foreach my $st (@statements) {
		my (undef, $p, $o)	= $st->nodes;
		my ($ns, $ln);
		try {
			($ns,$ln)	= $p->qname;
		} catch RDF::Trine::Error with {
			my $uri	= $p->uri_value;
			throw RDF::Trine::Error::SerializationError -text => "Can't turn predicate $uri into a QName.";
		};
		unless (exists $namespaces{ $ns }) {
			$namespaces{ $ns }	= 'ns' . $counter++;
		}
		my $prefix	= $namespaces{ $ns };
		if ($o->isa('RDF::Trine::Node::Literal')) {
			my $lv		= $o->literal_value;
			for ($lv) {
				s/&/&amp;/g;
				s/</&lt;/g;
				s/"/&quot;/g;
			}
			my $lang	= $o->literal_value_language;
			my $dt		= $o->literal_datatype;
			my $tag	= join(':', $prefix, $ln);
			if ($lang) {
				$string	.= qq[\t<${tag} xml:lang="${lang}">${lv}</${tag}>\n];
			} elsif ($dt) {
				$string	.= qq[\t<${tag} rdf:datatype="${dt}">${lv}</${tag}>\n];
			} else {
				$string	.= qq[\t<${tag}>${lv}</${tag}>\n];
			}
		} elsif ($o->isa('RDF::Trine::Node::Blank')) {
			my $b	= $o->blank_identifier;
			for ($b) {
				s/&/&amp;/g;
				s/</&lt;/g;
				s/"/&quot;/g;
			}
			$string	.= qq[\t<${prefix}:$ln rdf:nodeID="$b"/>\n];
		} else {
			my $u	= $o->uri_value;
			for ($u) {
				s/&/&amp;/g;
				s/</&lt;/g;
				s/"/&quot;/g;
			}
			$string	.= qq[\t<${prefix}:$ln rdf:resource="$u"/>\n];
		}
	}
	
	$string	.= qq[</rdf:Description>\n];
	
	# rdf namespace is already defined in the <rdf:RDF> tag, so ignore it here
	my %seen	= %{ $self->{namespaces} };
	my @ns;
	foreach my $uri (sort { $namespaces{$a} cmp $namespaces{$b} } grep { not($seen{$_}) } (keys %namespaces)) {
		my $ns	= $namespaces{$uri};
		my $str	= ($ns eq '') ? qq[xmlns="$uri"] : qq[xmlns:${ns}="$uri"];
		push(@ns, $str);
	}
	my $ns	= join(' ', @ns);
	if ($ns) {
		return qq[<rdf:Description ${ns} $id>\n] . $string;
	} else {
		return qq[<rdf:Description $id>\n] . $string;
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to RDF/XML, returning the result as a string.

=cut

sub _serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= {};
	
	my $ns		= $self->_top_xmlns();
	my $base_uri        = '';
	if ($self->{base_uri}) {
	  $base_uri = "xml:base=\"$self->{base_uri}\" ";
	}
	my $string	= qq[<?xml version="1.0" encoding="utf-8"?>\n<rdf:RDF $base_uri$ns>\n];
	$string		.= $self->__serialize_bounded_description( $model, $node, $seen );
	$string	.= qq[</rdf:RDF>\n];
	return $string;
}

sub __serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	return '' if ($seen->{ $node->sse }++);
	
	my $string	= '';
	my $st		= RDF::Trine::Statement->new( $node, map { RDF::Trine::Node::Variable->new($_) } qw(p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(p ASC o ASC) ] );
	
	my @bindings	= $iter->get_all;
	if (@bindings) {
		my @samesubj	= map { RDF::Trine::Statement->new( $node, $_->{p}, $_->{o} ) } @bindings;
		my @blanks		= grep { blessed($_) and $_->isa('RDF::Trine::Node::Blank') } map { $_->{o} } @bindings;
		$string			.= $self->_statements_same_subject_as_string( @samesubj );
		foreach my $object (@blanks) {
			$string	.= $self->__serialize_bounded_description( $model, $object, $seen );
		}
	}
	return $string;
}

sub _top_xmlns {
	my $self	= shift;
	my $namespaces	= $self->{namespaces};
	my @keys		= sort { $namespaces->{$a} cmp $namespaces->{$b} } keys %$namespaces;
	
	my @ns;
	foreach my $v (@keys) {
		my $k	= $namespaces->{$v};
		if (blessed($v)) {
			$v	= $v->uri_value;
		}
		my $str	= ($k eq '') ? qq[xmlns="$v"] : qq[xmlns:$k="$v"];
		push(@ns, $str);
	}
	my $ns		= join(' ', @ns);
	return $ns;
}

1;

__END__

=back

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-syntax-grammar/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
