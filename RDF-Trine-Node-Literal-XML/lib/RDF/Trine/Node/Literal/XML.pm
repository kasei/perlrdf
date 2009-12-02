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
use Scalar::Util qw(blessed refaddr);
use Carp qw(carp croak confess);
use XML::LibXML qw(:ns);

######################################################################

our ($VERSION, %XML_FRAGMENTS);
BEGIN {
	$VERSION	= '0.13';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new ( $node [ , $lang, $datatype ] ) >>

=item C<< new ( $string ) >>

Returns a new XML Literal object. This method can be used in two different ways:
It can either be passed a string or an XML::LibXML node.

In the case of passing a string, this method follows the same API as the
RDF::Trine::Node::Literal constructor, but:

* $string must be a well-balanced XML fragment
* $lang is optional, but if a language code is present it will be used as the value of C<< xml:lang >> attribute(s) on the root XML element(s) of the literal. If the element already has an C<< xml:lang >> attribute it will be overwritten.
* $datatype will be ignored and set to 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral'

In the case of using a XML::LibXML node C<< $node >>,
the Node may be one of these types or a subclass thereof:

  * XML::LibXML::Document
  * XML::LibXML::DocumentFragment
  * XML::LibXML::Element
  * XML::LibXML::CDATASection
  * XML::LibXML::NodeList

If the string is not a valid XML fragment, and the C<< $node >> is not
of one of the above types, this method throws a RDF::Trine::Error exception.

=cut

sub new {
	my $class	= shift;
	my $input	= shift;
	my $lang	= shift;

	my $typeok = _check_type($input); # First check if we have a valid node
	if ($typeok) { # Then use it
	  my $literal;
	  if ($input->isa('XML::LibXML::NodeList')) {
	    foreach my $context ($input->get_nodelist) {
	      if ($lang) {
		$context->setAttributeNS(XML_XML_NS, 'lang', $lang);
	      }
	      if ($context->ownerDocument) {
		$literal .= $context->toStringEC14N;
	      } else {
		$literal .= $context->toString;
	      }
	    }
	  } else {
	    if ($lang) {
	      if ($input->isa('XML::LibXML::Element')) {
		$input->setAttributeNS(XML_XML_NS, 'lang', $lang);
	      }
	      elsif ($input->isa('XML::LibXML::Document')) {
		my $root = $input->documentElement();
		$root->setAttributeNS(XML_XML_NS, 'lang', $lang);
	      }
	      elsif ($input->isa('XML::LibXML::DocumentFragment')) {
		foreach my $context ($input->childNodes) {
		  $context->setAttributeNS(XML_XML_NS, 'lang', $lang);
		}
	      } else {
		carp ref($input) . " doesn't support xml:lang attributes";
	      }
	    }
	    if ($input->ownerDocument) {
	      $literal = $input->toStringEC14N;
	    } else {
	      $literal = $input->toString;
	    }
	  }
	  my $self	= $class->SUPER::new( $literal, undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );
	  $XML_FRAGMENTS{ refaddr( $self ) }	= $input;
	  return $self;
	}

	if (ref($input) && (! $typeok)) { # Then it is neither a string nor a good type
	  throw RDF::Trine::Error -text => ref($input) . " is not a valid type.";
	}
	
        # Last chance is that it is a string with valid XML
        my $parser = XML::LibXML->new();
        my $doc = eval { $parser->parse_balanced_chunk( $input ) };
        if ($@) { # Didn't parse, so invalid XML string
	  throw RDF::Trine::Error -text => "$@";
	}

	if ($lang) {
	  foreach my $context ($doc->childNodes) {
	    $context->setAttributeNS(XML_XML_NS, 'lang', $lang);
	  }
	  $input = $doc->toString;
	}

        my $self = $class->SUPER::_new( $input, undef, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral' );

        $XML_FRAGMENTS{ refaddr( $self ) }	= $doc;
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
  return 0 unless blessed($type);
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

First created by Gregory Todd Williams <gwilliams@cpan.org>, modfied
and maintained by Kjetil Kjernsmo <kjetilk@cpan.org>

=cut
