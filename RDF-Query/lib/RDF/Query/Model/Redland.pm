package RDF::Query::Model::Redland;

use strict;
use warnings;
use base qw(RDF::Query::Model);

use Carp qw(carp croak confess);

use File::Spec;
use RDF::Redland 1.00;
use Data::Dumper;
use LWP::Simple qw(get);
use Scalar::Util qw(blessed reftype);
use Unicode::Normalize qw(normalize);
use Encode;

use RDF::Trine::Iterator;

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
		my $storage	= RDF::Redland::Storage->new( "hashes", "test", "new='yes',hash-type='memory',contexts='yes'" );
		$model	= RDF::Redland::Model->new( $storage, '' );
	}

	throw RDF::Query::Error::MethodInvocationError ( -text => 'Not a RDF::Redland::Model passed to bridge constructor' ) unless (blessed($model) and $model->isa('RDF::Redland::Model'));
	
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
		model		=> 'RDF::Redland::Model',
		statement	=> 'RDF::Redland::Statement',
		node		=> 'RDF::Redland::Node',
		resource	=> 'RDF::Redland::Node',
		literal		=> 'RDF::Redland::Node',
		blank		=> 'RDF::Redland::Node',
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
		my $node	= RDF::Redland::URI->new( $uri );
		return RDF::Redland::Node->new_from_uri( $node );
	}
}

=item C<new_literal ( $string, $language, $datatype )>

Returns a new literal object.

=cut

sub new_literal {
	my $self	= shift;
	my $value	= shift;
	my $lang	= shift;
	my $type	= shift;
	my @args	= ("$value");
	no warnings 'uninitialized';
	if ($type and $RDF::Redland::VERSION >= 1.00_02) {
		# $RDF::Redland::VERSION is introduced in 1.0.2, and that's also when datatypes are fixed.
		$type	= RDF::Redland::URI->new( $type );
		push(@args, $type);
		push(@args, undef);
	} elsif ($lang) {
		push(@args, undef);
		push(@args, $lang);
	}
	
	# XXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	# XXX hack... the values don't seem to work unless i print them out...
	# XXX popped up as an error when debugging the javascript net function...
	# XXX possibly an error in the XS in the JavaScript module
	my $buffer;
	open( my $fh, '>', \$buffer );
	print {$fh} Dumper(\@args);
	close($fh);
	# XXX XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	
	my $literal	= RDF::Redland::Node->new_literal( @args );
	return $literal;
}

=item C<new_blank ( $identifier )>

Returns a new blank node object.

=cut

sub new_blank {
	my $self	= shift;
	return RDF::Redland::Node->new_from_blank_identifier(@_);
}

=item C<new_statement ( $s, $p, $o )>

Returns a new statement object.

=cut

sub new_statement {
	my $self	= shift;
	return RDF::Redland::Statement->new(@_);
}

=item C<is_node ( $node )>

=item C<isa_node ( $node )>

Returns true if C<$node> is a node object for the current model.

=cut

sub isa_node {
	my $self	= shift;
	my $node	= shift;
	return UNIVERSAL::isa($node,'RDF::Redland::Node');
}

=item C<is_resource ( $node )>

=item C<isa_resource ( $node )>

Returns true if C<$node> is a resource object for the current model.

=cut

sub isa_resource {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return (ref($node) and $node->is_resource);
}

=item C<is_literal ( $node )>

=item C<isa_literal ( $node )>

Returns true if C<$node> is a literal object for the current model.

=cut

sub isa_literal {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	if ($node->isa('DateTime')) {
		return 1;
	} else {
		return (ref($node) and $node->is_literal);
	}
}

=item C<is_blank ( $node )>

=item C<isa_blank ( $node )>

Returns true if C<$node> is a blank node object for the current model.

=cut

sub isa_blank {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return (ref($node) and $node->is_blank);
}
*RDF::Query::Model::Redland::is_node		= \&isa_node;
*RDF::Query::Model::Redland::is_resource	= \&isa_resource;
*RDF::Query::Model::Redland::is_literal		= \&isa_literal;
*RDF::Query::Model::Redland::is_blank		= \&isa_blank;

=item C<< equals ( $node_a, $node_b ) >>

Returns true if C<$node_a> and C<$node_b> are equal

=cut

sub equals {
	my $self	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	return 1 if (not(defined($nodea)) and not(defined($nodeb)));
	return 0 unless blessed($nodea);
	return $nodea->equals( $nodeb );
}


=item C<as_string ( $node )>

Returns a string version of the node object.

=cut

sub as_string {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	my $string	= $node->as_string;
	return $string;
}

=item C<literal_value ( $node )>

Returns the string value of the literal object.

=cut

sub literal_value {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	if ($node->isa('DateTime')) {
		my $f	= DateTime::Format::W3CDTF->new;
		my $l	= $f->format_datetime( $node );
		return $l;
	} else {
		return decode('utf8', $node->literal_value) || '';
	}
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
		my $type	= $node->literal_datatype;
		return undef unless $type;
		return $type->as_string;
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
	my $lang	= $node->literal_value_language;
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
	return $node->uri->as_string;
}

=item C<blank_identifier ( $node )>

Returns the identifier for the blank node object.

=cut

sub blank_identifier {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return undef unless ($self->is_blank($node));
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
	my $format	= shift || 'guess';
	
	my $model		= $self->{model};
	my $parser		= RDF::Redland::Parser->new($format);
	
	my $data		= get( $uri );
	$data			= decode_utf8( $data );
	$self->add_string( $data, $uri, $named, $format );
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
	my $format	= shift || 'guess';
	
	my $data		= normalize( 'C', $_data );
	my $model		= $self->{model};
	my $parser		= RDF::Redland::Parser->new($format);
	my $redlanduri	= RDF::Redland::URI->new( $uri );
	
	if ($named) {
		my $stream		= $parser->parse_string_as_stream($data, $redlanduri);
		$model->add_statements( $stream, $redlanduri );
	} else {
		$parser->parse_string_into_model( $data, $redlanduri, $model );
	}
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

=item C<< _get_statements ($subject, $predicate, $object) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub _get_statements {
	my $self	= shift;
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	
#	warn "get_statements: <<" . join(', ', map { ref($_) ? $_->as_string : 'undef' } (@triple)) . ">> [" . (blessed($context) ? $context->as_string : '') . "]";
	
	my @defs	= grep defined, @triple;
	my $model	= $self->{'model'};
	my $stmt	= RDF::Redland::Statement->new( @triple );
	my $stream;
	
#	warn "GETTING " . $stmt->as_string if ($RDF::Query::debug);
	
	my %args	= ( bridge => $self );
	
	if ($context) {
		my $iter	= $model->find_statements( $stmt, $context );
		$args{ context }	= $context;
		$args{ named }		= 1;

		my $finished	= 0;
		$stream	= sub {
			$finished	= 1 if (@_ and $_[0] eq 'close');
			return undef if ($finished);
			if (@_ and $_[0] eq 'context') {
				return $context;
			} elsif (not $iter) {
				return undef;
			} elsif ($iter->end) {
				$iter	= undef;
				return undef;
			} else {
				my $ret	= $iter->current;
				$iter->next;
				my $ctx	= blessed($context) ? $context->as_string : '';
#				warn ">>>>> " . $ret->as_string . "\t<$ctx>\n" if (blessed($ret));	# XXX
				return $ret;
			}
		};
	} else {
		if (scalar(@defs) == 2) {
			my @imethods	= qw(sources_iterator arcs_iterator targets_iterator);
			my @smethods	= qw(subject predicate object);
			my ($imethod, $smethod);
			foreach my $i (0 .. 2) {
				if (not defined $triple[ $i ]) {
					$imethod	= $imethods[ $i ];
					$smethod	= $smethods[ $i ];
					last;
				}
			}
			my $iter	= $model->$imethod( @defs );
			my $context;
			my $finished	= 0;
			$stream	= sub {
				$finished	= 1 if (@_ and $_[0] eq 'close');
				return undef if ($finished);
				if (@_ and $_[0] eq 'context') {
					return $context;
				} elsif (not $iter) {
					return undef;
				} elsif ($iter->end) {
					$iter	= undef;
					return undef;
				} else {
					my $ret	= $iter->current;
					$context	= $iter->context;
					$iter->next;
					my $s	= $stmt->clone;
					$s->$smethod( $ret );
					my $ctx	= blessed($context) ? $context->as_string : '';
#					warn ">>>>> " . $s->as_string . "\t<$ctx>\n" if (blessed($s));	# XXX
					return $s;
				}
			};
		} else {
			my $iter	= $model->find_statements( $stmt );
			warn "iterator: $iter (" . $stmt->as_string . ')' if (0);
			my $finished	= 0;
			my $context;
			$stream	= sub {
				$finished	= 1 if (@_ and $_[0] eq 'close');
				return undef if ($finished);
				no warnings 'uninitialized';
				if (@_ and $_[0] eq 'context') {
					return $context;
				} elsif (not $iter) {
					return undef;
				} elsif ($iter->end) {
					$context	= $iter->context;
					$iter	= undef;
					return undef;
				} else {
					my $ret	= $iter->current;
					$context	= $iter->context;
					$iter->next;
					my $ctx	= blessed($context) ? $context->as_string : '';
#					warn ">>>>> " . $ret->as_string . "\t<$ctx>\n" if (blessed($ret));	# XXX
					return $ret;
				}
			};
		}
	}
	
	return RDF::Trine::Iterator::Graph->new( $stream, %args );
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


=begin private

=item C<< ignore_contexts >>

=end private

=cut

sub ignore_contexts {
	my $self	= shift;
	# no-op
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
	
	Carp::confess "Not a CODE reference: " . Dumper($stream) unless (reftype($stream) eq 'CODE');
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
	
	return 1 if ($feature eq 'temp_model');
	return 1 if ($feature eq 'named_graph');
	return 1 if ($feature eq 'named_graphs');
	return 1 if ($feature eq 'xml');
#	return 1 if ($feature eq 'node_counts');	# XXX just used for testing -- redland doesn't have efficient statement counting. see C<node_count> below.
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
	my $st		= RDF::Redland::Statement->new( @_ );
	my $stream	= $model->find_statements( $st );
	my $count	= 0;
	while ($stream and not $stream->end) {
		$count++;
		$stream->next;
	}
	
	return 0 unless ($total);
	return $count / $total;
}


=item C<as_xml ($stream)>

Returns an RDF/XML serialization of the results graph.

=cut

sub as_xml {
	my $self	= shift;
	my $iter	= shift;
	return undef unless $iter->is_graph;
	my $storage	= RDF::Redland::Storage->new("hashes", "test", "new='yes',hash-type='memory'");
	my $model	= RDF::Redland::Model->new($storage, "");
	while (my $st = $iter->current) {
		$model->add_statement( $st );
		$iter->next;
	}
	
	my $base		= RDF::Redland::URI->new('http://example.com/');
	my $serializer	= RDF::Redland::Serializer->new("rdfxml");	# rdfxml-abbrev was emitting empty documents... reverted to plain rdfxml
	my $xml			= $serializer->serialize_model_to_string( $base, $model );
	return $xml;
}


sub RDF::Redland::Node::getLabel {
	my $node	= shift;
	if ($node->type == $RDF::Redland::Node::Type_Resource) {
		return $node->uri->as_string;
	} elsif ($node->type == $RDF::Redland::Node::Type_Literal) {
		return $node->literal_value;
	} elsif ($node->type == $RDF::Redland::Node::Type_Blank) {
		return $node->blank_identifier;
	}
}


=item C<< model_as_stream >>

Returns an iterator object containing every statement in the model.

=cut

sub model_as_stream {
	my $self	= shift;
	my $model	= $self->model;
	return $model->as_stream;
}



=item C<< debug >>

Prints debugging information about the model (including all statements in the
model) to STDERR.

=cut

sub debug {
	my $self	= shift;
	my $stream	= $self->model_as_stream();
	warn "------------------------------\n";
	while (my $st = $stream->current) {
		my $string	= $self->as_string( $st );
		if (my $c 	= $stream->context) {
			my $cs	= $c->as_string;
			$string	.= "\tC<$cs>";
		}
		print STDERR "$string\n";
	} continue { $stream->next }
	warn "------------------------------\n";
}

1;

__END__

=back

=cut
