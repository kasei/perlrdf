package RDF::Query::Model::RDFBase;

use strict;
use warnings;
use base qw(RDF::Query::Model);

use Carp qw(carp croak confess);

use RDF::Query::Error;
use File::Spec;
use RDF::Base;
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Encode;

use RDF::SPARQLResults;

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 174 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=item C<new ( $model )>

Returns a new bridge object for the specified C<$model>.

=cut

sub new {
	my $class	= shift;
	my $model	= shift;
	my %args	= @_;
	
	if (not defined $model) {
		my $storage	= RDF::Base::Storage::Memory->new();
		$model	= RDF::Base::Model->new( storage => $storage );
	}

	throw RDF::Query::Error::MethodInvocationError ( -text => 'Not a RDF::Base::Model passed to bridge constructor' ) unless (blessed($model) and $model->isa('RDF::Base::Model'));
	
	my $self	= bless( {
					model	=> $model,
					parsed	=> $args{parsed},
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
		model		=> 'RDF::Base::Model',
		statement	=> 'RDF::Base::Statement',
		node		=> 'RDF::Base::Node',
		resource	=> 'RDF::Base::Node::Resource',
		literal		=> 'RDF::Base::Node::Literal',
		blank		=> 'RDF::Base::Node::Blank',
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
	my $node	= RDF::Base::Node::Resource->new( uri => $uri );
	return $node;
}

=item C<new_literal ( $string, $language, $datatype )>

Returns a new literal object.

=cut

sub new_literal {
	my $self	= shift;
	my $value	= shift;
	my $lang	= shift;
	my $type	= shift;
	my %args	= ( value => $value );
	no warnings 'uninitialized';
	if ($type) {
		$args{ datatype }	= RDF::Base::Node::Resource->new( uri => $type );
	} elsif ($lang) {
		$args{ language }	= $lang;
	}
	
	return RDF::Base::Node::Literal->new( %args );
}

=item C<new_blank ( $identifier )>

Returns a new blank node object.

=cut

sub new_blank {
	my $self	= shift;
	return RDF::Base::Node::Blank->new( (@_) ? (name => $_[0]) : () );
}

=item C<new_statement ( $s, $p, $o )>

Returns a new statement object.

=cut

sub new_statement {
	my $self	= shift;
	my ($s, $p, $o)	= @_;
	return RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o );
}

=item C<new_variable ( $name )>

Returns a new variable object.

=cut

sub new_variable {
	my $self	= shift;
	my $name	= shift;
	return RDF::Base::Node::Variable->new( name => $name );
}

=item C<is_node ( $node )>

=item C<isa_node ( $node )>

Returns true if C<$node> is a node object for the current model.

=cut

sub isa_node {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Base::Node'));
}

=item C<is_resource ( $node )>

=item C<isa_resource ( $node )>

Returns true if C<$node> is a resource object for the current model.

=cut

sub isa_resource {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Base::Node::Resource'));
}

=item C<is_literal ( $node )>

=item C<isa_literal ( $node )>

Returns true if C<$node> is a literal object for the current model.

=cut

sub isa_literal {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Base::Node::Literal'));
}

=item C<is_blank ( $node )>

=item C<isa_blank ( $node )>

Returns true if C<$node> is a blank node object for the current model.

=cut

sub isa_blank {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Base::Node::Blank'));
}
*RDF::Query::Model::RDFBase::is_node		= \&isa_node;
*RDF::Query::Model::RDFBase::is_resource	= \&isa_resource;
*RDF::Query::Model::RDFBase::is_literal		= \&isa_literal;
*RDF::Query::Model::RDFBase::is_blank		= \&isa_blank;

=item C<< equals ( $node_a, $node_b ) >>

Returns true if C<$node_a> and C<$node_b> are equal

=cut

sub equals {
	my $self	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	return $nodea->equal( $nodeb );
}


=item C<as_string ( $node )>

Returns a string version of the node object.

=cut

sub as_string {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return $node->as_string;
}

=item C<literal_value ( $node )>

Returns the string value of the literal object.

=cut

sub literal_value {
	my $self	= shift;
	my $node	= shift;
	return $node->literal_value;
}

=item C<literal_datatype ( $node )>

Returns the datatype of the literal object.

=cut

sub literal_datatype {
	my $self	= shift;
	my $node	= shift;
	my $type	= $node->datatype;
	return $type;
}

=item C<literal_value_language ( $node )>

Returns the language of the literal object.

=cut

sub literal_value_language {
	my $self	= shift;
	my $node	= shift;
	my $lang	= $node->language;
	return $lang;
}

=item C<uri_value ( $node )>

Returns the URI string of the resource object.

=cut

sub uri_value {
	my $self	= shift;
	my $node	= shift;
	return unless ($node);
	return $node->uri_value;
}

=item C<blank_identifier ( $node )>

Returns the identifier for the blank node object.

=cut

sub blank_identifier {
	my $self	= shift;
	my $node	= shift;
	return $node->blank_identifier;
}

=item C<add_uri ( $uri, $named, $format )>

Addsd the contents of the specified C<$uri> to the model.
If C<$named> is true, the data is added to the model using C<$uri> as the
named context.

=cut

sub add_uri {
	my $self	= shift;
	my $uri		= shift;
	my $named	= shift;
	my $format	= shift;
	my $model	= $self->model;
	my $parser	= RDF::Base::Parser->new( ($format) ? (name => $format) : () );
	$uri		= RDF::Base::Node::Resource->new( uri => $uri );
	$parser->parse_into_model( $uri, $uri, $model );
}

=item C<add_string ( $data, $base_uri, $named, $format )>

Added the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

sub add_string {
	my $self	= shift;
	my $data	= shift;
	my $base	= shift;
	my $named	= shift;
	my $format	= shift;
	
	my $uri		= RDF::Base::Node::Resource->new( uri => $base );
	my $parser	= RDF::Base::Parser->new( name => $format );
	$parser->parse_string_into_model( $data, $uri, $self->model );
}

=item C<statement_method_map ()>

Returns an ordered list of method names that when called against a statement
object will return the subject, predicate, and object objects, respectively.

=cut

sub statement_method_map {
	return qw(subject predicate object);
}

=item C<< subject ( $statement ) >>

Returns the subject node of the specified C<$statement>.

=cut

sub subject {
	my $self	= shift;
	my $stmt	= shift;
	return $stmt->subject;
}

=item C<< predicate ( $statement ) >>

Returns the predicate node of the specified C<$statement>.

=cut

sub predicate {
	my $self	= shift;
	my $stmt	= shift;
	return $stmt->predicate;
}

=item C<< object ( $statement ) >>

Returns the object node of the specified C<$statement>.

=cut

sub object {
	my $self	= shift;
	my $stmt	= shift;
	return $stmt->object;
}

=item C<get_statements ($subject, $predicate, $object)>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	
	my @defs	= grep defined, @triple;
	my $model	= $self->{'model'};
	my $stream;
	
	my %args	= ( bridge => $self, named => 1 );
	
	my $iter	= $model->get_statements( @triple, $context );
	if ($context) {
		$args{ context }	= $context;

		my $finished	= 0;
		$stream	= sub {
			$finished	= 1 if (@_ and $_[0] eq 'close');
			return undef if ($finished);
			if (@_ and $_[0] eq 'context') {
				return $context;
			} elsif (not $iter) {
				return undef;
			} else {
				my $data	= $iter->next;
				if (defined $data) {
					$context	= $data->context;
					return $data;
				} else {
					$finished	= 1;
					return;
				}
			}
		};
	} else {
		my $finished	= 0;
		my $context;
		$stream	= sub {
			$finished	= 1 if (@_ and $_[0] eq 'close');
			return undef if ($finished);
			no warnings 'uninitialized';
			if (@_ and $_[0] eq 'context') {
				return $context;
			} elsif (not $iter) {
				return;
			} else {
				my $data	= $iter->next;
				if (defined $data) {
					$context	= $data->context;
					return $data;
				} else {
					$finished	= 1;
					return;
				}
			}
		};
	}
	
	return RDF::SPARQLResults::Graph->new( $stream, %args );
}

=item C<< multi_get ( triples => \@triples, order => $order ) >>

XXX

=cut

sub multi_get {
	my $self	= shift;
	my %args	= @_;
	my $triples	= $args{ triples };
	my $order	= $args{ order };
	
	my $count	= scalar(@$triples);
	throw RDF::Query::Error::SimpleQueryPatternError if ($count > 4);
	warn "${count} statements in multi-get" if ($debug);
	
	my @node_names	= qw(subject predicate object context);
	
	my @statements;
	foreach my $i (0 .. $#{ $triples }) {
		my $triple	= $triples->[ $i ];
		my %statement;
		foreach my $j (0 .. $#{ $triple }) {
			my $name	= $node_names[ $j ];
			my $node	= $triple->[ $j ];
			if (reftype($node) eq 'ARRAY') {
				if ($node->[0] eq 'VAR' or $node->[0] eq 'BLANK') {
					$statement{ $name }	= RDF::Base::Node::Variable->new( name => $node->[1] );
				} else {
					throw RDF::Query::Error::SimpleQueryPatternError ( -text => "Only variables should be arrays at this point. Why isn't $node->[0] an object?" );
				}
			} else {
				$statement{ $name }	= $node;
			}
		}
		my $st	= RDF::Base::Statement->new( %statement );
		$statements[ $i ]	= $st;
	}
	
	my $iter	= $self->model->multi_get( triples => \@statements, order => $order );
	return $iter;
}

=item C<< add_statement ( $statement ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $model	= $self->model;
	$model->add_statement( $stmt );
}

=item C<< remove_statement ( $statement ) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $model	= $self->model;
	$model->remove_statement( $stmt );
}








=item C<get_context ($stream)>

Returns the context node of the last statement retrieved from the specified
C<$stream>. The stream object, in turn, calls the closure (that was passed to
the stream constructor in C<get_statements>) with the argument 'context'.

=cut

sub get_context {
	my $self	= shift;
	my $stream	= shift;
	my %args	= @_;
	
	if (0) {
		Carp::cluck "get_context stream: ";
		local($RDF::Query::debug)	= 2;
		RDF::Query::_debug_closure( $stream );
	}
	
	my $context	= $stream->('context');
	return $context;
}

=item C<supports ($feature)>

Returns true if the underlying model supports the named C<$feature>.
Possible features include:

	* named_graph
	* node_counts
	* temp_model
	* xml

=cut

sub supports {
	my $self	= shift;
	my $feature	= shift;
	
	return 1 if ($feature =~ m/^(temp_model|named_graph|node_counts)$/);
	no strict 'refs';
	
	if ($feature eq 'multi_get') {
		return 1 if ($self->model->supports( $feature ));
	}
	return 0;
}

=item C<node_count ( $subj, $pred, $obj )>

Returns a number representing the frequency of statements in the
model matching the given triple. This number is used in cost analysis
for query optimization, and has a range of [0, 1] where zero represents
no matching triples in the model and one represents matching all triples
in the model.

=cut

sub node_count {
	my $self	= shift;
	my $model	= $self->model;
	my $total	= $model->size;
	my $count	= $model->count_statements( @_ );
	
	return 0 unless ($total);
	return $count / $total;
}


1;

__END__

=back

=cut
