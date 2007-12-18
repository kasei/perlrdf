package RDF::Query::Model::RDFCore;

use strict;
use warnings;
use base qw(RDF::Query::Model);

use Carp qw(carp croak);

use File::Spec;
use RDF::Core::Model;
use RDF::Core::Query;
use RDF::Core::Model::Parser;
use RDF::Core::Storage::Memory;
use RDF::Core::NodeFactory;
use RDF::Core::Model::Serializer;
use Scalar::Util qw(blessed);
use Unicode::Normalize qw(normalize);

use RDF::Iterator;

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 301 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	eval "use LWP::Simple ();";
	our $LWP_SUPPORT	= ($@) ? 0 : 1;
}

######################################################################

=head1 METHODS

=over 4

=item C<new ( $model )>

Returns a new bridge object for the specified C<$model>.

=cut

sub new {
	my $proto	= shift;
	my $class	= ref($proto) || $proto;
	my $model	= shift;
	my %args	= @_;
	
	if (not defined $model) {
		my $storage	= new RDF::Core::Storage::Memory;
		$model	= new RDF::Core::Model (Storage => $storage);
	}
	
	unless (blessed($model) and $model->isa('RDF::Core::Model')) {
		throw RDF::Query::Error::MethodInvocationError ( -text => 'Not a RDF::Core::Model object passed to bridge constructor' ) 
	}
	
	my $factory	= new RDF::Core::NodeFactory;
	my $self	= bless( {
					model	=> $model,
					parsed	=> $args{parsed},
					factory	=> $factory,
					sttime	=> time,
					counter	=> 0
				}, $class );
}

=item C<< meta () >>

Returns a hash reference with information (class names) about the underlying
backend. The keys of this hash are 'class', 'model', 'statement', 'node',
'resource', 'literal', and 'blank'.

'class' is the name of the bridge class. All other keys refer to backend classes.
For example, 'node' is the backend superclass of all node objects (literals,
resources and blanks).

=cut

sub meta {
	return {
		class		=> __PACKAGE__,
		model		=> 'RDF::Core::Model',
		statement	=> 'RDF::Core::Statement',
		node		=> 'RDF::Core::Node',
		resource	=> 'RDF::Core::Resource',
		literal		=> 'RDF::Core::Literal',
		blank		=> 'RDF::Core::Node',
	};
}

=item C<model ()>

Returns the underlying model object.

=cut

sub model {
	my $self	= shift;
	return $self->{'model'};
}

=item C<new_resource ( $uri )>

Returns a new resource object.

=cut

sub new_resource {
	my $self	= shift;
	my $uri		= shift;
	if ($self->is_resource( $uri )) {
		return $uri;
	} else {
		return RDF::Core::Resource->new( $uri );
	}
}

=item C<new_literal ( $string, $language, $datatype )>

Returns a new literal object.

=cut

sub new_literal {
	my $self	= shift;
	return RDF::Core::Literal->new(@_);
}

=item C<new_blank ( $identifier )>

Returns a new blank node object.

=cut

sub new_blank {
	my $self	= shift;
	my $id		= shift;
	unless ($id) {
		$id	= 'r' . $self->{'sttime'} . 'r' . $self->{'counter'}++;
	}
	return $self->{'factory'}->newResource("_:${id}");
}

=item C<new_statement ( $s, $p, $o )>

Returns a new statement object.

=cut

sub new_statement {
	my $self	= shift;
	return RDF::Core::Statement->new(@_);
}

=item C<is_node ( $node )>

=item C<isa_node ( $node )>

Returns true if C<$node> is a node object for the current model.

=cut

sub isa_node {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return $node->isa('RDF::Core::Node');
}

=item C<is_resource ( $node )>

=item C<isa_resource ( $node )>

Returns true if C<$node> is a resource object for the current model.

=cut

sub isa_resource {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	my $rsrc	= ($node->isa('RDF::Core::Resource'));
	if ($rsrc) {
		my $label	= $node->getLabel;
		return ($label !~ m/^_:/);
	} else {
		return;
	}
}

=item C<is_literal ( $node )>

=item C<isa_literal ( $node )>

Returns true if C<$node> is a literal object for the current model.

=cut

sub isa_literal {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return $node->isa('RDF::Core::Literal');
}

=item C<is_blank ( $node )>

=item C<isa_blank ( $node )>

Returns true if C<$node> is a blank node object for the current model.

=cut

sub isa_blank {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return ($node->isa('RDF::Core::Resource') and $node->getURI =~ /^_:/);
}
*RDF::Query::Model::RDFCore::is_node		= \&isa_node;
*RDF::Query::Model::RDFCore::is_resource	= \&isa_resource;
*RDF::Query::Model::RDFCore::is_literal		= \&isa_literal;
*RDF::Query::Model::RDFCore::is_blank		= \&isa_blank;

=item C<< equals ( $node_a, $node_b ) >>

Returns true if C<$node_a> and C<$node_b> are equal

=cut

sub equals {
	my $self	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	if ($self->isa_resource( $nodea ) and $self->isa_resource( $nodeb )) {
		return ($self->uri_value( $nodea ) eq $self->uri_value( $nodeb ));
	} elsif ($self->isa_literal( $nodea ) and $self->isa_literal( $nodeb )) {
		my @values	= map { $self->literal_value( $_ ) } ($nodea, $nodeb);
		my @langs	= map { $self->literal_value_language( $_ ) } ($nodea, $nodeb);
		my @types	= map { $self->literal_datatype( $_ ) } ($nodea, $nodeb);
		
		if ($values[0] eq $values[1]) {
			no warnings 'uninitialized';
			if (@langs) {
				return ($langs[0] eq $langs[1]);
			} elsif (@types) {
				return ($types[0] eq $types[1]);
			} else {
				return 1;
			}
		} else {
			return 0;
		}
	} elsif ($self->isa_blank( $nodea ) and $self->isa_blank( $nodeb )) {
		return ($self->blank_identifier( $nodea ) eq $self->blank_identifier( $nodeb ));
	} else {
		return 0;
	}
}


=item C<as_string ( $node )>

Returns a string version of the node object.

=cut

sub as_string {
	my $self	= shift;
	my $node	= shift;
	return unless blessed($node);
	if ($self->isa_resource( $node )) {
		my $uri	= $node->getLabel;
		return qq<[$uri]>;
	} elsif ($self->isa_literal( $node )) {
		my $value	= $self->literal_value( $node );
		my $lang	= $self->literal_value_language( $node );
		my $dt		= $self->literal_datatype( $node );
		if ($lang) {
			return qq["$value"\@${lang}];
		} elsif ($dt) {
			return qq["$value"^^<$dt>];
		} else {
			return qq["$value"];
		}
	} elsif ($self->isa_blank( $node )) {
		my $id	= $self->blank_identifier( $node );
		return qq[($id)];
	} elsif (blessed($node) and $node->isa('RDF::Core::Statement')) {
		return $node->getLabel;
	} else {
		return;
	}
}

=item C<literal_value ( $node )>

Returns the string value of the literal object.

=cut

sub literal_value {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return $node->getLabel;
}

=item C<literal_datatype ( $node )>

Returns the datatype of the literal object.

=cut

sub literal_datatype {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return unless ($self->is_literal($node));
	if ($node->isa('DateTime')) {
		return 'http://www.w3.org/2001/XMLSchema#dateTime';
	} else {
		my $type	= $node->getDatatype;
		return $type;
	}
}

=item C<literal_value_language ( $node )>

Returns the language of the literal object.

=cut

sub literal_value_language {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return undef unless ($self->is_literal($node));
	my $lang	= $node->getLang;
	return $lang;
}

=item C<uri_value ( $node )>

Returns the URI string of the resource object.

=cut

sub uri_value {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return undef unless ($self->is_resource($node));
	return $node->getLabel;
}

=item C<blank_identifier ( $node )>

Returns the identifier for the blank node object.

=cut

sub blank_identifier {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return undef unless ($self->is_blank($node));
	my $label	= $node->getLabel;
	$label		=~ s/^_://;
	return $label;
}

=item C<add_uri ( $uri, $named )>

Addsd the contents of the specified C<$uri> to the model.
If C<$named> is true, the data is added to the model using C<$uri> as the
named context.

=cut

sub add_uri {
	my $self	= shift;
	my $url		= shift;
	my $named	= shift;
	
	our $LWP_SUPPORT;
	unless ($LWP_SUPPORT) {
		die "LWP::Simple is not available for loading external data";
	}
	
	$self->set_context( $url );
	my $rdf		= LWP::Simple::get($url);
	my %options = (
				Model		=> $self->{'model'},
				Source		=> $rdf,
				SourceType	=> 'string',
				BaseURI		=> $url,
				BNodePrefix	=> "genid" . $self->{counter}++ . 'r',
			);
	my $parser	= new RDF::Core::Model::Parser (%options);
	$parser->parse;
}

=item C<add_string ( $data, $base_uri, $named, $format )>

Addsd the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

sub add_string {
	my $self	= shift;
	my $_data	= shift;
	my $uri		= shift;
	my $named	= shift;
	
	my $data	= normalize( 'C', $_data );
	$self->set_context( $uri );
	my %options = (
				Model		=> $self->{'model'},
				Source		=> $data,
				SourceType	=> 'string',
				BNodePrefix	=> "genid" . $self->{counter}++ . 'r',
			);
	$options{ BaseURI }	= $uri if ($uri);
	my $parser	= new RDF::Core::Model::Parser (%options);
	$parser->parse;
}

=item C<< set_context ( $url ) >>

Sets the context of triples in this model.

=cut

sub set_context {
	my $self	= shift;
	my $name	= shift;
	if (exists($self->{context}) and not($self->{ignore_contexts})) {
		Carp::confess "RDF::Core models can only represent a single context" unless ($self->{context} eq $name);
	}
	$self->{context}	= $name;
}

=begin private

=item C<< ignore_contexts >>

=end private

=cut

sub ignore_contexts {
	my $self	= shift;
	$self->{ignore_contexts}	= 1;
}

=item C<< get_context () >>

If the triples in this model are named, returns the resource object representing
the context. Otherwise returns undef.

=cut

sub get_context {
	my $self	= shift;
	if (exists($self->{context})) {
		return $self->new_resource( $self->{context} );
	} else {
		return;
	}
}

=item C<statement_method_map ()>

Returns an ordered list of method names that when called against a statement
object will return the subject, predicate, and object objects, respectively.

=cut

sub statement_method_map {
	return qw(getSubject getPredicate getObject);
}

=item C<< subject ( $statement ) >>

Returns the subject node of the specified C<$statement>.

=cut

sub subject {
	my $self	= shift;
	my $stmt	= shift;
	return $stmt->getSubject;
}

=item C<< predicate ( $statement ) >>

Returns the predicate node of the specified C<$statement>.

=cut

sub predicate {
	my $self	= shift;
	my $stmt	= shift;
	return $stmt->getPredicate;
}

=item C<< object ( $statement ) >>

Returns the object node of the specified C<$statement>.

=cut

sub object {
	my $self	= shift;
	my $stmt	= shift;
	return unless (blessed($stmt));
	return $stmt->getObject;
}

=item C<get_statements ($subject, $predicate, $object)>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	if ($context) {
		unless ($self->equals( $context, $self->get_context)) {
			return RDF::Iterator::Graph->new( sub {undef}, bridge => $self );
		}
	}
	
	my $enum	= $self->{'model'}->getStmts( @triple );
	my $stmt	= $enum->getNext;
	my $finished	= 0;
	my $stream	= sub {
		$finished	= 1 if (@_ and $_[0] eq 'close');
		$finished	= 1 unless defined($stmt);
		return undef if ($finished);
		
		my $ret	= $stmt;
		$stmt	= $enum->getNext;
		return $ret;
	};
	
	return RDF::Iterator::Graph->new( $stream, bridge => $self );
}

=item C<< add_statement ( $statement ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $model	= $self->model;
	$model->addStmt( $stmt );
}

=item C<< remove_statement ( $statement ) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $model	= $self->model;
	$model->removeStmt( $stmt );
}

=item C<supports ($feature)>

Returns true if the underlying model supports the named C<$feature>.
Possible features include:

	* named_graph
	* xml

=cut

sub supports {
	my $self	= shift;
	my $feature	= shift;
	
	return 1 if ($feature eq 'temp_model');
	return 1 if ($feature eq 'xml');
	return 0;
}

=item C<as_xml ($stream)>

Returns an RDF/XML serialization of the results graph.

=cut

sub as_xml {
	my $self	= shift;
	my $iter	= shift;
	return undef unless $iter->is_graph;
	my $storage	= new RDF::Core::Storage::Memory;
	my $model	= new RDF::Core::Model (Storage => $storage);
	while ($iter and not $iter->finished) {
		$model->addStmt( $iter->current );
	} continue { $iter->next }
	my $xml;
	my $serializer	= RDF::Core::Model::Serializer->new(
						Model	=> $model,
						Output	=> \$xml,
					);
	$serializer->serialize;
	return $xml;
}

1;

__END__

=back

=cut

