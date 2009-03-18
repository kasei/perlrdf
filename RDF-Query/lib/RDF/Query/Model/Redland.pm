package RDF::Query::Model::Redland;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Model);

use Carp qw(carp croak confess);

use Log::Log4perl;
use File::Spec;
use Data::Dumper;
use LWP::UserAgent;
use Scalar::Util qw(blessed reftype);
use Encode;

use RDF::Redland 1.00;
use RDF::Trine::Iterator;
use RDF::Trine::Statement::Quad;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.100';
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
	my $self	= shift;
	return {
		class		=> __PACKAGE__,
		model		=> 'RDF::Redland::Model',
		store		=> 'RDF::Redland::Storage',
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

=item C<< equals ( $node_a, $node_b ) >>

Returns true if C<$node_a> and C<$node_b> are equal

=cut

sub equals {
	my $self	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	return 1 if (not(defined($nodea)) and not(defined($nodeb)));
	return 0 unless blessed($nodea);
	return $nodea->equal( $nodeb );
}


=item C<add_uri ( $uri, $named, $format )>

Addsd the contents of the specified C<$uri> to the model.
If C<$named> is true, the data is added to the model using C<$uri> as the
named context.

=cut

sub add_uri {
	my $self		= shift;
	my $uri			= shift;
	my $named		= shift;
	my $format		= shift || 'guess';
	
	my $model		= $self->{model};
	my $parser		= RDF::Redland::Parser->new($format);
	
	my $ua			= LWP::UserAgent->new( agent => "RDF::Query/${RDF::Query::VERSION}" );
	$ua->default_headers->push_header( 'Accept' => "application/rdf+xml;q=0.5, text/turtle;q=0.7, text/xml" );
	
	my $resp		= $ua->get( $uri );
	unless ($resp->is_success) {
		warn "No content available from $uri: " . $resp->status_line;
		return;
	}
	my $data		= $resp->content;
	$data			= decode_utf8( $data );
	$self->add_string( $data, $uri, $named, $format );
}

=item C<add_string ( $data, $base_uri, $named, $format )>

Adds the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

sub add_string {
	my $self	= shift;
	my $_data	= shift;
	my $base	= shift;
	my $named	= shift;
	my $format	= shift || 'guess';
	my $l		= Log::Log4perl->get_logger("rdf.query.model.redland");
	
	my $model	= ($named) ? $self->_named_graphs_model : $self->model;
	
	my $data		= $_data;
	my $parser		= RDF::Redland::Parser->new($format);
	my $redlanduri	= RDF::Redland::URI->new( $base );
	
	if ($named) {
		$l->debug("adding named data with name ($base) to model " . Dumper($model) . ": $data\n");
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
	my $model	= $self->model;
	
	@triple		= map { _cast_to_redland( $_ ) } @triple;
	my $stmt	= RDF::Redland::Statement->new( @triple );
	my @defs	= grep defined, @triple;
	my $stream;
	
#	warn "GETTING " . $stmt->as_string if ($RDF::Query::debug);
	
	my %args	= ( bridge => $self );
	
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
		my $finished	= 0;
		$stream	= sub {
			$finished	= 1 if (@_ and $_[0] eq 'close');
			return undef if ($finished);
			if (not $iter) {
				return undef;
			} elsif ($iter->end) {
				$iter	= undef;
				return undef;
			} else {
				my $ret		= $iter->current;
				my $context	= $iter->context;
				$iter->next;
				my $s		= $stmt->clone;
				$s->$smethod( $ret );
				return ($s, $context);
			}
		};
	} else {
		my $iter	= $model->find_statements( $stmt );
		warn "iterator: $iter (" . $stmt->as_string . ')' if (0);
		my $finished	= 0;
		$stream	= sub {
			$finished	= 1 if (@_ and $_[0] eq 'close');
			return undef if ($finished);
			no warnings 'uninitialized';
			if (not $iter) {
				return undef;
			} elsif ($iter->end) {
				$iter	= undef;
				return undef;
			} else {
				my $ret		= $iter->current;
				my $context	= $iter->context;
				$iter->next;
				return ($ret, $context);
			}
		};
	}
	
	my $iter	= sub {
		my ($rstmt, $context)	= $stream->();
		return unless ($rstmt);
		my $rs		= $rstmt->subject;
		my $rp		= $rstmt->predicate;
		my $ro		= $rstmt->object;
		my @nodes;
		foreach my $n ($rs, $rp, $ro) {
			push(@nodes, _cast_to_local( $n ));
		}
		my $st	= RDF::Trine::Statement->new( @nodes );
		return $st;
	};
	
	return RDF::Trine::Iterator::Graph->new( $iter, %args );
}

=item C<< _get_named_statements ( $subject, $predicate, $object, $context ) >>

Returns a stream object of all statements matching the specified subject,
predicate, object and context. Any of the arguments may be undef to match
any value.

=cut

sub _get_named_statements {
	my $self		= shift;
	my @triple		= splice(@_, 0, 3);
	Carp::confess 'no context' unless (@_);
	my $_context	= shift;
	my $model		= $self->_named_graphs_model;
	
	@triple		= map { _cast_to_redland( $_ ) } @triple;
	my $stmt	= RDF::Redland::Statement->new( @triple );
	
	my $context	= _cast_to_redland( $_context );
	my @context	= ($context) ? $context : ();
	my $iter	= $model->find_statements( $stmt, @context );
	
	my $finished	= 0;
	my $stream	= sub {
		$finished	= 1 if (@_ and $_[0] eq 'close');
		return undef if ($finished);
		if (not $iter) {
			return undef;
		} elsif ($iter->end) {
			$iter	= undef;
			return undef;
		} else {
			my $rstmt	= $iter->current;
			my $rc		= $iter->context;
			$iter->next;
			my $rs		= $rstmt->subject;
			my $rp		= $rstmt->predicate;
			my $ro		= $rstmt->object;
			my @nodes;
			foreach my $n ($rs, $rp, $ro, $rc) {
				push(@nodes, _cast_to_local( $n ));
			}
			my $st	= RDF::Trine::Statement::Quad->new( @nodes );
			return $st;
		}
	};
	return RDF::Trine::Iterator::Graph->new( $stream );
}


sub _cast_to_redland {
	my $node	= shift;
	return undef unless (blessed($node));
	if ($node->isa('RDF::Trine::Statement')) {
		my @nodes	= map { _cast_to_redland( $_ ) } $node->nodes;
		return RDF::Redland::Statement->new( @nodes );
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		return RDF::Redland::Node->new_from_uri( $node->uri_value );
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		return RDF::Redland::Node->new_from_blank_identifier( $node->blank_identifier );
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $lang	= $node->literal_value_language;
		my $dt		= $node->literal_datatype;
		my $value	= $node->literal_value;
		return RDF::Redland::Node->new_literal( "$value", $dt, $lang );
	} else {
		return undef;
	}
}

sub _cast_to_local {
	my $node	= shift;
	return undef unless (blessed($node));
	my $type	= $node->type;
	if ($type == $RDF::Redland::Node::Type_Resource) {
		return RDF::Query::Node::Resource->new( $node->uri->as_string );
	} elsif ($type == $RDF::Redland::Node::Type_Blank) {
		return RDF::Query::Node::Blank->new( $node->blank_identifier );
	} elsif ($type == $RDF::Redland::Node::Type_Literal) {
		my $lang	= $node->literal_value_language;
		my $dturi	= $node->literal_datatype;
		my $dt		= ($dturi)
					? $dturi->as_string
					: undef;
		return RDF::Query::Node::Literal->new( decode('utf8', $node->literal_value), $lang, $dt );
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
	my $rstmt	= _cast_to_redland( $stmt );
	$model->add_statement( $rstmt );
}

=item C<< remove_statement ( $statement ) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $model	= $self->model;
	my $rstmt	= _cast_to_redland( $stmt );
	$model->remove_statement( $rstmt );
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
	my $st		= RDF::Redland::Statement->new( map { _cast_to_redland($_) } @_ );
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
	my $model	= shift || $self->model;
	return $model->as_stream;
}



=item C<< debug >>

Prints debugging information about the model (including all statements in the
model) to STDERR.

=cut

sub debug {
	my $self	= shift;
	my $model	= shift || $self->model;
	my $l		= Log::Log4perl->get_logger("rdf.query.model.redland");
	my $stream	= $self->model_as_stream( $model );
	$l->debug("------------------------------");
	while (my $st = $stream->current) {
		my $string	= $self->as_string( $st );
		if (my $c 	= $stream->context) {
			my $cs	= $c->as_string;
			$string	.= "\tC<$cs>";
		}
		$l->debug($string);
		$stream->next;
	}
	$l->debug("------------------------------");
}

sub _named_graphs_model {
	my $self	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.model.redland");
	if ($self->{named_graphs}) {
		$l->debug("named graphs model: " . Dumper($self->{named_graphs}));
		return $self->{named_graphs};
	} else {
		my $storage	= RDF::Redland::Storage->new( "hashes", "test", "new='yes',hash-type='memory',contexts='yes'" );
		my $model	= RDF::Redland::Model->new( $storage, '' );
		$self->{named_graphs}	= $model;
		$l->debug("creating new graphs model: " . Dumper($self->{named_graphs}));
		return $model;
	}
}


1;

__END__

=back

=cut
