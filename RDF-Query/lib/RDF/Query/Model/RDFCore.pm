package RDF::Query::Model::RDFCore;

use strict;
use warnings;
use base qw(RDF::Query::Model);

use Carp qw(carp croak);

use File::Spec;
use LWP::UserAgent;
use RDF::Core::Model;
use RDF::Core::Query;
use RDF::Core::Model::Parser;
use RDF::Core::Storage::Memory;
use RDF::Core::NodeFactory;
use RDF::Core::Model::Serializer;
use Scalar::Util qw(blessed);
use Unicode::Normalize qw(normalize);

use RDF::Trine::Iterator;
use RDF::Trine::Statement::Quad;

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 301 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
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

=item C<< equals ( $nodea, $nodeb ) >>

Returns true if the two nodes are equal, false otherwise.

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


# =item C<as_string ( $node )>
# 
# Returns a string version of the node object.
# 
# =cut
# 
# sub as_string {
# 	my $self	= shift;
# 	my $node	= shift;
# 	return unless blessed($node);
# 	if ($self->isa_resource( $node )) {
# 		my $uri	= $node->getLabel;
# 		return qq<[$uri]>;
# 	} elsif ($self->isa_literal( $node )) {
# 		my $value	= $self->literal_value( $node );
# 		my $lang	= $self->literal_value_language( $node );
# 		my $dt		= $self->literal_datatype( $node );
# 		if ($lang) {
# 			return qq["$value"\@${lang}];
# 		} elsif ($dt) {
# 			return qq["$value"^^<$dt>];
# 		} else {
# 			return qq["$value"];
# 		}
# 	} elsif ($self->isa_blank( $node )) {
# 		my $id	= $self->blank_identifier( $node );
# 		return qq[($id)];
# 	} elsif (blessed($node) and $node->isa('RDF::Core::Statement')) {
# 		return $node->getLabel;
# 	} else {
# 		return;
# 	}
# }

=item C<add_uri ( $uri, $named )>

Addsd the contents of the specified C<$uri> to the model.
If C<$named> is true, the data is added to the model using C<$uri> as the
named context.

=cut

sub add_uri {
	my $self	= shift;
	my $url		= shift;
	my $named	= shift;
	
	$self->set_context( $url );
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Query/${RDF::Query::VERSION}" );
	$ua->default_headers->push_header( 'Accept' => "application/rdf+xml;q=0.5, text/turtle;q=0.7, text/xml" );
	
	my $resp	= $ua->get( $url );
	unless ($resp->is_success) {
		warn "No content available from $url: " . $resp->status_line;
		return;
	}
	my $rdf	= $resp->content;
	
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
#	return qw(getSubject getPredicate getObject);
	return qw(subject predicate object);
}

=item C<< _get_statements ($subject, $predicate, $object [, $context]) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub _get_statements {
	my $self	= shift;
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	
	@triple		= map { _cast_to_rdfcore( $_ ) } @triple;
	
	if ($context) {
		if ($self->equals( $context, $self->get_context)) {
			# 
		} else {
			return RDF::Trine::Iterator::Graph->new( sub {undef}, bridge => $self );
		}
	}
	
	my $enum	= $self->{'model'}->getStmts( @triple );
	my $stmt	= $enum->getNext;
	my $finished	= 0;
	my $stream	= sub {
		$finished	= 1 if (@_ and $_[0] eq 'close');
		$finished	= 1 unless defined($stmt);
		return undef if ($finished);
		
		my $rstmt	= $stmt;
		$stmt	= $enum->getNext;
		
		my $rs		= $rstmt->getSubject;
		my $rp		= $rstmt->getPredicate;
		my $ro		= $rstmt->getObject;
		my @nodes;
		foreach my $n ($rs, $rp, $ro) {
			push(@nodes, _cast_to_trine( $n ));
		}
		my $st	= ($context)
				? RDF::Trine::Statement->new( @nodes )
				: RDF::Trine::Statement::Quad->new( @nodes, $context );
		return $st;
	};
	
	return RDF::Trine::Iterator::Graph->new( $stream, bridge => $self );
}

sub _cast_to_rdfcore {
	my $node	= shift;
	return undef unless (blessed($node));
	if ($node->isa('RDF::Trine::Node::Resource')) {
		return RDF::Core::Resource->new( $node->uri_value );
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		return RDF::Core::Resource->new( '_:' . $node->blank_identifier );
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $lang	= $node->literal_value_language;
		my $dt		= $node->literal_datatype;
		return RDF::Core::Literal->new( $node->literal_value, $lang, $dt );
	} else {
		return undef;
	}
}

sub _cast_to_trine {
	my $node	= shift;
	return unless (blessed($node));
	if ($node->isLiteral) {
		my $lang	= $node->getLang;
		my $dt		= $node->getDatatype;
		return RDF::Trine::Node::Literal->new( $node->getValue, $lang, $dt );
	} elsif ($node->isa('RDF::Core::Resource') and $node->getURI =~ /^_:/) {
		my $label	= $node->getLabel;
		$label		=~ s/^_://;
		return RDF::Trine::Node::Blank->new( $label );
	} elsif ($node->isa('RDF::Core::Resource')) {
		return RDF::Trine::Node::Resource->new( $node->getLabel );
	} else {
		return undef;
	}
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

