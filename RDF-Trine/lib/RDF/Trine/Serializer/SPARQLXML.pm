# RDF::Trine::Serializer::SPARQLXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::SPARQLXML - SPARQL XML Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::SPARQLXML version 0.135

=head1 SYNOPSIS

 use RDF::Trine::Serializer::SPARQLXML;
 my $serializer	= RDF::Trine::Serializer::SPARQLXML->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::SPARQLXML class provides an API for serializing RDF
variable bindings sets to the SPARQL XML syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::SPARQLXML;

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
	$RDF::Trine::Serializer::serializer_names{ 'sparqlxml' }	= __PACKAGE__;
	$RDF::Trine::Serializer::format_uris{ 'http://www.w3.org/ns/formats/SPARQL_Results_XML' }	= __PACKAGE__;
	foreach my $type (qw(application/sparql-results+xml)) {
		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

Returns a new SPARQLXML serializer object.

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
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $self->serialize_iterator_to_file( $file, $iter );
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to SPARQL XML, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $st		= RDF::Trine::Statement->new( map { RDF::Trine::Node::Variable->new($_) } qw(s p o) );
	my $pat		= RDF::Trine::Pattern->new( $st );
	my $iter	= $model->get_pattern( $pat, undef, orderby => [ qw(s ASC p ASC o ASC) ] );
	return $self->serialize_iterator_to_string( $iter );
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
	
	no strict 'refs';
	print {$fh} <<"END";
<?xml version="1.0" encoding="utf-8"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
END
	
	my $t	= join("\n", map { qq(\t<variable name="$_"/>) } @variables);
	
	my $delay_output	= 0;
	my $delayed			= '';
	
	if ($iter->extra_result_data) {
		$delay_output	= $fh;
		undef $fh;
		open( $fh, '>', \$delayed ) or die $!;
	} else {
		if ($t) {
			print {$fh} "${t}\n";
		}
	}
	
	print {$fh} <<"END";
</head>
<results>
END
	
	my $count	= 0;
	while (my $row = $iter->next) {
		my @row;
		print {$fh} "\t\t<result>\n";
		for (my $i = 0; $i < $width; $i++) {
			my $name	= $iter->binding_name($i);
			my $value	= $row->{ $name };
			print {$fh} "\t\t\t" . $iter->format_node_xml($value, $name) . "\n";
		}
		print {$fh} "\t\t</result>\n";
		
		last if ($max_result_size and ++$count >= $max_result_size);
	}
	
	if ($delay_output) {
		my $extra = $iter->extra_result_data;
		my $extraxml	= '';
		foreach my $tag (keys %$extra) {
			$extraxml	.= qq[<extra name="${tag}">\n];
			my $value	= $extra->{ $tag };
			foreach my $e (@$value) {
				foreach my $k (keys %$e) {
					my $v		= $e->{ $k };
					my @values	= @$v;
					foreach ($k, @values) {
						s/&/&amp;/g;
						s/</&lt;/g;
						s/"/&quot;/g;
					}
					$extraxml	.= qq[\t<extrakey id="$k">] . join(',', @values) . qq[</extrakey>\n];
				}
			}
			$extraxml	.= "</extra>\n";
		}
		my $u	= URI->new('data:');
		$u->media_type('text/xml');
		$u->data($extraxml);
		my $uri	= "$u";
		$uri	=~ s/&/&amp;/g;
		$uri	=~ s/</&lt;/g;
		$uri	=~ s/'/&apos;/g;
		$uri	=~ s/"/&quot;/g;
		
		$fh		= $delay_output;
		print {$fh} "${t}\n";
		print {$fh} qq[\t<link href="$uri" />\n];
		print {$fh} $delayed;
	}
	
	print {$fh} "</results>\n</sparql>\n";
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to N-Triples, returning the result as a string.

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

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-sparql-XMLres/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
