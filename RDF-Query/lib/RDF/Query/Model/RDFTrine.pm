package RDF::Query::Model::RDFTrine;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Model);

use Carp qw(carp croak confess);

use File::Spec;
use File::Temp qw(tempfile);
use Data::Dumper;
use Scalar::Util qw(blessed reftype refaddr);
use LWP::UserAgent;
use Encode;
use Error qw(:try);

use RDF::Query::Model::RDFTrine::Filter;
use RDF::Query::Model::RDFTrine::BasicGraphPattern;

use RDF::Trine 0.102;
use RDF::Trine::Model;
use RDF::Trine::Parser;
use RDF::Trine::Pattern;
use RDF::Trine::Iterator;
use RDF::Trine::Store::DBI;
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.002';
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
		my $store	= RDF::Trine::Store::DBI->temporary_store();
		$model		= RDF::Trine::Model->new( $store );
	}

	throw RDF::Query::Error::MethodInvocationError ( -text => 'Not a RDF::Trine::Store::DBI passed to bridge constructor' ) unless (blessed($model) and ($model->isa('RDF::Trine::Store::DBI') or $model->isa('RDF::Trine::Model')));
	
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
		model		=> 'RDF::Trine::Store::DBI',
		statement	=> 'RDF::Query::Algebra::Triple',
		node		=> 'RDF::Trine::Node',
		resource	=> 'RDF::Trine::Node::Resource',
		literal		=> 'RDF::Trine::Node::Literal',
		blank		=> 'RDF::Trine::Node::Blank',
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
	return $nodea->equal( $nodeb );
}


=item C<as_string ( $node )>

Returns a string version of the node object.

=cut

sub as_string {
	my $self	= shift;
	my $node	= shift;
	return unless blessed($node);
	if ($self->isa_resource( $node )) {
		my $uri	= $node->uri_value;
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
	} elsif (blessed($node) and $node->isa('RDF::Query::Algebra::Triple')) {
		return $node->as_sparql;
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
	return unless ($self->is_literal( $node ));
	return $node->literal_value;
}

=item C<literal_datatype ( $node )>

Returns the datatype of the literal object.

=cut

sub literal_datatype {
	my $self	= shift;
	my $node	= shift;
	return unless ($self->is_literal( $node ));
	my $type	= $node->literal_datatype;
	return $type;
}

=item C<literal_value_language ( $node )>

Returns the language of the literal object.

=cut

sub literal_value_language {
	my $self	= shift;
	my $node	= shift;
	return unless ($self->is_literal( $node ));
	my $lang	= $node->literal_value_language;
	return $lang;
}

=item C<uri_value ( $node )>

Returns the URI string of the resource object.

=cut

sub uri_value {
	my $self	= shift;
	my $node	= shift;
	return unless ($self->is_resource( $node ));
	return $node->uri_value;
}

=item C<blank_identifier ( $node )>

Returns the identifier for the blank node object.

=cut

sub blank_identifier {
	my $self	= shift;
	my $node	= shift;
	return unless ($self->is_blank( $node ));
	return $node->blank_identifier;
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
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Query/${RDF::Query::VERSION}" );
	$ua->default_headers->push_header( 'Accept' => "application/rdf+xml;q=0.5, text/turtle;q=0.7, text/xml" );
	
	my $resp	= $ua->get( $uri );
	unless ($resp->is_success) {
		warn "No content available from $uri: " . $resp->status_line;
		return;
	}
	my $content	= $resp->content;
	$self->add_string( $content, $uri, $named, $format );
}

=item C<add_string ( $data, $base_uri, $named, $format )>

Adds the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

sub add_string {
	my $self	= shift;
	my $data	= shift;
	my $base	= shift;
	my $named	= shift;
	my $format	= shift || 'guess';
	
	my $graph	= RDF::Query::Node::Resource->new( $base );
	my $model	= ($named) ? $self->_named_graphs_model : $self->model;
	
# 	our $USE_RAPPER;
# 	if ($USE_RAPPER) {
# 		if ($data !~ m/<rdf:RDF/ms) {
# 			my ($fh, $filename) = tempfile();
# 			print $fh $data;
# 			close($fh);
# 			$data	= do {
# 								open(my $fh, '-|', "rapper -q -i turtle -o rdfxml $filename") or die $!;
# 								local($/)	= undef;
# 								my $data	= <$fh>;
# 								my $c		= $self->{counter}++;
# 								$data		=~ s/nodeID="([^"]+)"/nodeID="r${c}r$1"/smg;
# 								$data;
# 							};
# 			unlink($filename);
# 		}
# 	}
	
	my $handler	= ($named)
				? sub { my $st	= shift; $model->add_statement( $st, $graph ) }
				: sub { my $st	= shift; $model->add_statement( $st ) };
	
	if ($data =~ m/<rdf:RDF/ms) {
		my $parser	= RDF::Trine::Parser->new('rdfxml');
		$parser->parse( $base, $data, $handler );
# 		
# 		require RDF::Redland;
# 		my $uri		= RDF::Redland::URI->new( $base );
# 		my $parser	= RDF::Redland::Parser->new($format);
# 		my $stream	= $parser->parse_string_as_stream($data, $uri);
# 		while ($stream and !$stream->end) {
# 			my $statement	= $stream->current;
# 			my $stmt		= ($named)
# 							? RDF::Query::Algebra::Quad->from_redland( $statement, $graph )
# 							: RDF::Query::Algebra::Triple->from_redland( $statement );
# 			$model->add_statement( $stmt );
# 			$stream->next;
# 		}
	} else {
		my $parser	= RDF::Trine::Parser->new('turtle');
		$parser->parse( $base, $data, $handler );
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
	my @nodes	= map { blessed($_) ? $_ : $self->new_variable() } @triple;
	if ($debug) {
		warn "statement pattern: " . Dumper(\@nodes);
		warn "model contains:\n";
		$model->_debug;
	}
	my $stream	= smap { _cast_triple_to_local( $_ ) } $model->get_statements( @nodes );
	return $stream;
}

=item C<< _get_named_statements ( $subject, $predicate, $object, $context ) >>

Returns a stream object of all statements matching the specified subject,
predicate, object and context. Any of the arguments may be undef to match
any value.

=cut

sub _get_named_statements {
	my $self	= shift;
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	
	my $model	= $self->_named_graphs_model;
	my @nodes	= map { $self->is_node($_) ? $_ : $self->new_variable() } (@triple, $context);
	my $stream	= smap { _cast_quad_to_local( $_ ) } $model->get_statements( @nodes );
	return $stream;
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
	return 0;
}

=item C<< fixup ( $pattern, $query, $base, \%namespaces ) >>

Called prior to query execution, if the underlying model can optimize
the execution of C<< $pattern >>, this method returns a optimized
RDF::Query::Algebra object to replace C<< $pattern >>. Otherwise, returns
C<< undef >> and the C<< fixup >> method of C<< $pattern >> will be used
instead.

=cut

sub fixup {
	my $self	= shift;
	my $pattern	= shift;
	my $query	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if ($pattern->isa('RDF::Query::Algebra::BasicGraphPattern') and not(scalar(@{$query->get_computed_statement_generators}))) {
		# call fixup on the triples so that they get converted to bridge-native objects
		my @triples		= map { $_->fixup( $query, $self, $base, $ns ) } $pattern->triples;
		my $tpattern	= RDF::Trine::Pattern->new( @triples );
		return RDF::Query::Model::RDFTrine::BasicGraphPattern->new( $tpattern, $pattern );
	} elsif ($pattern->isa('RDF::Query::Algebra::Filter')) {
		my $filter	= $pattern;
		my $ggp	= $filter->pattern;
		if ($ggp->isa('RDF::Query::Algebra::GroupGraphPattern')) {
			warn "pattern is a ggp" if ($debug);
			my @patterns	= $ggp->patterns;
			if (scalar(@patterns) == 1 and $patterns[0]->isa('RDF::Query::Algebra::BasicGraphPattern')) {
				warn "'-> pattern is a bgp" if ($debug);
				my $bgp	= $patterns[0];
				my $compiled;
				try {
					$self->model->_store->_sql_for_pattern( $filter );
					$compiled	= RDF::Query::Model::RDFTrine::Filter->new( $filter );
					warn "    '-> filter can be compiled to RDF::Trine" if ($debug);
					warn "        '-> " . Dumper($compiled) if ($debug);
				} otherwise {
					warn "    '-> filter CANNOT be compiled to RDF::Trine" if ($debug);
				};
				return $compiled;
			} else {
				return;
			}
		} else {
			return;
		}
	} else {
		return;
	}
}

sub _named_graphs_model {
	my $self	= shift;
	if ($self->{named_graphs}) {
		return $self->{named_graphs};
	} else {
		my $store	= RDF::Trine::Store::DBI->temporary_store();
		my $model	= RDF::Trine::Model->new( $store );
		$self->{named_graphs}	= $model;
		return $model;
	}
}

sub _cast_triple_to_local {
	my $st	= shift;
	return undef unless ($st);
	return RDF::Query::Algebra::Triple->new( map { _cast_to_local( $st->$_() ) } qw(subject predicate object) );
}

sub _cast_quad_to_local {
	my $st	= shift;
	return undef unless ($st);
	return RDF::Query::Algebra::Quad->new( map { _cast_to_local( $st->$_() ) } qw(subject predicate object context) );
}

sub _cast_to_local {
	my $node	= shift;
	return undef unless (blessed($node));
	if ($node->isa('RDF::Trine::Node::Literal')) {
		return RDF::Query::Node::Literal->new( $node->literal_value, $node->literal_value_language, $node->literal_datatype );
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		return RDF::Query::Node::Blank->new( $node->blank_identifier );
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		return RDF::Query::Node::Resource->new( $node->uri_value );
	} else {
		return undef;
	}
}

1;

__END__

=back

=cut
