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
* $lang will be ignored, and set to undef
* $datatype will be ignored and set to 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral'

If these conditions are not met, this method throws a RDF::Trine::Error exception.

=cut

sub new {
	my $class	= shift;
	my $literal	= shift;
	
	my $self	= $class->SUPER::_new( $literal, undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	
	my $parser = XML::LibXML->new();
	my $doc = eval { $parser->parse_balanced_chunk( $literal ) };
	if ($@) {
		throw RDF::Trine::Error -text => "$@";
	}
	
	$XML_FRAGMENTS{ refaddr( $self ) }	= $doc;
	return $self;
}

=item C<< new_from_node ( $node ) >>

Returns a new XML Literal object using an XML::LibXML type C<< $node >>. 
The Node may be one of these types or a subclass thereof:

  * XML::LibXML::Document
  * XML::LibXML::DocumentFragment
  * XML::LibXML::Element
  * XML::LibXML::CDATASection
  * XML::LibXML::NodeList


=cut

sub new_from_node {
	my $class	= shift;
	my $node	= shift;

	unless (_check_type($node)) {
	  throw RDF::Trine::Error -text => ref($node) . " is not a valid type.";
	}

	my $literal;
	if ($node->isa('XML::LibXML::NodeList')) {
	  foreach my $context ($node->get_nodelist) {
	    $literal .= $context->toString;
	  }
	} else {
	  $literal = $node->toString;
	}

	my $self	= $class->SUPER::new( $literal, undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	$XML_FRAGMENTS{ refaddr( $self ) }	= $node;
	return $self;
}

=item C<< xml_element >>

Returns the XML::LibXML node for the XML Literal.

=cut

sub xml_element {
	my $self	= shift;
	my $node	= $XML_FRAGMENTS{ refaddr( $self ) };
	unless (blessed($node)) {
		throw RDF::Trine::Error -text => "No XML element found for object";
	}
	return $node;
}

# Check if we have an acceptable type
sub _check_type {
  my $type = shift;
  return ($type->isa('XML::LibXML::Document') ||
	  $type->isa('XML::LibXML::DocumentFragment') ||
	  $type->isa('XML::LibXML::Element') ||
	  $type->isa('XML::LibXML::CDATASection') ||
	  $type->isa('XML::LibXML::NodeList') );
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
