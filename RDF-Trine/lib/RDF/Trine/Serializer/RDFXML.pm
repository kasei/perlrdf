# RDF::Trine::Serializer::RDFXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::RDFXML - RDF/XML Serializer.

=head1 VERSION

This document describes RDF::Trine::Serializer::RDFXML version 0.112_03

=head1 SYNOPSIS

 use RDF::Trine::Serializer::RDFXML;
 my $serializer	= RDF::Trine::Serializer::RDFXML->new();

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Serializer::RDFXML;

use strict;
use warnings;

use URI;
use Carp;
use XML::SAX;
use Data::Dumper;
use Scalar::Util qw(blessed);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.112_03';
}

######################################################################

=item C<< new >>

Returns a new 

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	$class = ref($class) || $class;
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
	print {$fh} qq[<?xml version="1.0" encoding="utf-8"?>\n<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n];
	while (my $st = $iter->next) {
		print {$fh} $self->_statement_as_string( $st );
	}
	print {$fh} qq[</rdf:RDF>\n];
}

sub _statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my ($s,$p,$o)	= $st->nodes;
	my $id;
	
	my $string	= '';
	if ($s->is_blank) {
		my $b	= $s->blank_identifier;
		$id	= qq[rdf:nodeID="$b"];
	} else {
		my $i	= $s->uri_value;
		$id	= qq[rdf:about="$i"];
	}
	$string	.= qq[<rdf:Description $id>\n];
	my ($ns,$ln)	= $self->_split_predicate( $p );
	if ($o->is_literal) {
		my $lv		= $o->literal_value;
		$lv			=~ s/&/&amp;/g;
		$lv			=~ s/</&lt;/g;
		my $lang	= $o->literal_value_language;
		my $dt		= $o->literal_datatype;
		if ($lang) {
			$string	.= qq[\t<$ln xmlns="$ns" xml:lang="${lang}">${lv}</$ln>\n];
		} elsif ($dt) {
			$string	.= qq[\t<$ln xmlns="$ns" rdf:datatype="${dt}">${lv}</$ln>\n];
		} else {
			$string	.= qq[\t<$ln xmlns="$ns">${lv}</$ln>\n];
		}
	} elsif ($o->is_blank) {
		my $b	= $o->blank_identifier;
		$string	.= qq[\t<$ln xmlns="$ns" rdf:nodeID="$b"/>\n];
	} else {
		my $u	= $o->uri_value;
		$string	.= qq[\t<$ln xmlns="$ns" rdf:resource="$u"/>\n];
	}
	$string	.= qq[</rdf:Description>\n];
	return $string;
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

sub _serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	return '' if ($seen->{ $node->sse }++);
	my $iter	= $model->get_statements( $node, undef, undef );
	
	my $string	= qq[<?xml version="1.0" encoding="utf-8"?>\n<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n];
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->_statement_as_string( $st );
		if ($nodes[2]->is_blank) {
			$string	.= $self->__serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	$string	.= qq[</rdf:RDF>\n];
	return $string;
}

sub __serialize_bounded_description {
	my $self	= shift;
	my $model	= shift;
	my $node	= shift;
	my $seen	= shift || {};
	return '' if ($seen->{ $node->sse }++);
	my $iter	= $model->get_statements( $node, undef, undef );
	
	my $string	= '';
	while (my $st = $iter->next) {
		my @nodes	= $st->nodes;
		$string		.= $self->_statement_as_string( $st );
		if ($nodes[2]->is_blank) {
			$string	.= $self->__serialize_bounded_description( $model, $nodes[2], $seen );
		}
	}
	return $string;
}

sub _split_predicate {
	my $self	= shift;
	my $p		= shift;
	my $uri		= $p->uri_value;
	
	my $nameStartChar	= qr<([A-Za-z:_]|[\x{C0}-\x{D6}]|[\x{D8}-\x{D8}]|[\x{F8}-\x{F8}]|[\x{200C}-\x{200C}]|[\x{37F}-\x{1FFF}][\x{200C}-\x{200C}]|[\x{2070}-\x{2070}]|[\x{2C00}-\x{2C00}]|[\x{3001}-\x{3001}]|[\x{F900}-\x{F900}]|[\x{FDF0}-\x{FDF0}]|[\x{10000}-\x{10000}])>;
	my $nameChar		= qr<$nameStartChar|-|[.]|[0-9]|\x{B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]>;
	my $lnre			= qr<((${nameStartChar})($nameChar)*)>;
	if ($uri =~ m/${lnre}$/) {
		my $ln	= $1;
		my $ns	= substr($uri, 0, length($uri)-length($ln));
#		warn "QName: " . Dumper([$ns,$ln]);
		return ($ns, $ln);
	} else {
		throw RDF::Trine::Error::SerializationError -text => "Can't turn predicate $uri into a QName.";
	}
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
