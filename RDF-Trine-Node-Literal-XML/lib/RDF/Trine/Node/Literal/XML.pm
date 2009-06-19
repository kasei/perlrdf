# RDF::Trine::Node::Literal::XML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Literal::XML - RDF Node class for XMLLiterals

=cut

package RDF::Trine::Node::Literal::XML;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node::Literal);

use RDF::Trine::Error qw(:try);
use Data::Dumper;
use Scalar::Util qw(blessed refaddr);
use Carp qw(carp croak confess);
use XML::LibXML;

######################################################################

our ($VERSION, %XML_FRAGMENTS);
BEGIN {
	$VERSION	= '0.001_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $string, $lang, $datatype )>

Returns a new XML Literal object. This method follows the same API as the
RDF::Trine::Node::Literal constructor, but:

* $string must be a valid XML fragment
* $lang must be undef
* $datatype must be 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral'

If these conditions are not met, this method throws a RDF::Trine::Error exception.

=cut

sub new {
	my $class	= shift;
	my $literal	= shift;
	my $lang	= shift;
	my $dt		= shift;
	
	unless (defined($dt) and $dt eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral') {
		throw RDF::Trine::Error -text => "Cannot create an XMLLiteral object without rdf:XMLLiteral datatype";
	}
	
	my $self	= $class->SUPER::_new( $literal, $lang, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	
	my $parser = XML::LibXML->new();
	my $doc = eval { $parser->parse_string( "<rdf-wrapper>${literal}</rdf-wrapper>" ) };
	if ($@) {
		throw RDF::Trine::Error -text => "$@";
	}
	
	$XML_FRAGMENTS{ refaddr( $self ) }	= $doc->documentElement;
	return $self;
}

=item C<< new_from_element ( $el ) >>

Returns a new XML Literal object using the XML::LibXML::Element C<< $el >>.

=cut

sub new_from_element {
	my $class	= shift;
	my $el		= shift;
	my $literal	= $el->toString;
	my $self	= $class->SUPER::new( $literal, undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	$XML_FRAGMENTS{ refaddr( $self ) }	= $el;
	return $self;
}

=item C<< xml_element >>

Returns the XML::LibXML::Element object for the XML Literal. If this XML Literal
object was constructed with C<< new >>, this element contains the '<rdf-wrapper>'
parent-XML-element, otherwise it is the element object passed to C<< new_from_element >>.

=cut

sub xml_element {
	my $self	= shift;
	my $el		= $XML_FRAGMENTS{ refaddr( $self ) };
	unless (blessed($el)) {
		throw RDF::Trine::Error -text => "No XML element found for object";
	}
	return $el;
}

sub DESTROY {
	my $self	= shift;
	delete $XML_FRAGMENTS{ refaddr( $self ) };
	
	if ($self->can('SUPER::DESTROY')) {
		$self->SUPER::DESTROY();
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
