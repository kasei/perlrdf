# RDF::Query::Model::RDFTrine
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model::RDFTrine - An RDF::Query::Model backend for interfacing with an RDF::Trine model.

=head1 VERSION

This document describes RDF::Query::Model::RDFTrine version 2.200, released 6 August 2009.

=cut

package RDF::Query::Model::RDFTrine;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Model);

use Carp qw(carp croak confess);

use Log::Log4perl;
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
use RDF::Trine qw(iri);
use RDF::Trine::Model;
use RDF::Trine::Parser;
use RDF::Trine::Pattern;
use RDF::Trine::Iterator;
use RDF::Trine::Store::DBI;
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200';
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
	my $self	= shift;
	my $meta	= {
		class		=> __PACKAGE__,
		statement	=> 'RDF::Query::Algebra::Triple',
		node		=> 'RDF::Trine::Node',
		resource	=> 'RDF::Trine::Node::Resource',
		literal		=> 'RDF::Trine::Node::Literal',
		blank		=> 'RDF::Trine::Node::Blank',
	};
	
	if (blessed($self)) {
		$meta->{ model }	= ref($self->model);
		$meta->{ store }	= ref($self->model->_store);
	} else {
		$meta->{ model }	= 'RDF::Trine::Model';
		$meta->{ store }	= 'RDF::Trine::Store';
	}
	return $meta;
}

=item C<model ()>

Returns the underlying model object.

=cut

sub model {
	my $self	= shift;
	unless (blessed($self)) {
		throw RDF::Query::Error::MethodInvocationError -text => "RDF::Query::Model::RDFTrine::model() cannot be called as a class method";
	}
	return $self->{'model'};
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
	
	unless ($named) {
		my $model	= $self->model;
		my $ok		= 0;
		try {
			RDF::Trine::Parser->parse_url_into_model( $uri, $model );
			$ok	= 1;
		} catch RDF::Trine::Error::ParserError with {};
		if ($ok) {
			return;
		}
	}
	
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
	
#	$self->model->_debug;
	return;
}

=item C<add_string ( $data, $base_uri, $named )>

Adds the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

sub add_string {
	my $self	= shift;
	my $data	= shift;
	my $base	= shift;
	my $named	= shift;
	
	my $graph	= iri( $base );
	my $model	= ($named) ? $self->_named_graphs_model : $self->model;
	
	my @named	= ($named) ? (context => iri($base)) : ();
	my $pname	= 'turtle';
	if ($data =~ /<rdf:RDF/ms) {
		$pname	= 'rdfxml';
	} elsif ($data =~ /XHTML[+]RDFa/) {
		$pname	= 'rdfa';
	}
	my $parser	= RDF::Trine::Parser->new($pname);
	$parser->parse_into_model( $base, $data, $model, @named );
	return;
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
	my $l		= Log::Log4perl->get_logger("rdf.query.model.rdftrine");
	
	my $model	= $self->model;
	my @nodes	= map { blessed($_) ? $_ : $self->new_variable() } @triple;
	if ($l->is_trace) {
		$l->trace("statement pattern: " . Dumper(\@nodes));
		$l->trace("model contains:");
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
	my $l		= Log::Log4perl->get_logger("rdf.query.model.rdftrine");
	
	my $model	= $self->_named_graphs_model;
	my @nodes	= map { $self->is_node($_) ? $_ : $self->new_variable() } (@triple, $context);
	
	if ($l->is_trace) {
		$l->trace("named statement pattern: " . Dumper(\@nodes));
		$l->trace("model contains:");
		$model->_debug;
	}

	my $stream	= smap { _cast_quad_to_local( $_ ) } $model->get_statements( @nodes );
	return $stream;
}

=item C<< _get_basic_graph_pattern ( @triples ) >>

Returns a stream object of all variable bindings matching the specified RDF::Trine::Statement objects.

=cut

sub _get_basic_graph_pattern {
	my $self	= shift;
	my @triples	= @_;
	my $model	= ($triples[0]->isa('RDF::Trine::Statement::Quad'))
				? $self->_named_graphs_model
				: $self->model;
	
	my $l		= Log::Log4perl->get_logger("rdf.query.model.rdftrine");
	if ($l->is_trace) {
		$l->trace("get BGP: " . Dumper(\@triples));
		$l->trace("model contains:");
		$model->_debug;
	}
	
	my $pattern	= RDF::Trine::Pattern->new( @triples );
	my $stream	= smap {
					foreach my $k (keys %$_) {
						$_->{ $k }	= _cast_to_local($_->{ $k })
					}
					$_
				} $model->get_pattern( $pattern );
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

=item C<count_statements ($subject, $predicate, $object)>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	return $self->model->count_statements( @_ );
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
	my @nodes	= @_[0..2];
	foreach my $i (0..2) {
		if (blessed($nodes[$i]) and $nodes[$i]->isa('RDF::Trine::Node::Variable')) {
			$nodes[$i]	= undef;
		}
	}
	my $model	= $self->model;
	my $total	= $self->count_statements();
	
	my $count	= $self->count_statements( @nodes );
	return 0 unless ($total);
	return $count / $total;
}

=item C<supports ($feature)>

Returns true if the underlying model supports the named C<$feature>.
Possible features include:

	* basic_graph_pattern
	* named_graph
	* node_counts
	* temp_model
	* xml

=cut

sub supports {
	my $self	= shift;
	my $feature	= shift;
	my $meta	= $self->meta;
	if ($meta->{store} eq 'RDF::Trine::Store::Hexastore') {
		return 1 if ($feature eq 'node_counts');
	}
	return 1 if ($feature eq 'basic_graph_pattern');
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
	my $l		= Log::Log4perl->get_logger("rdf.query.model.rdftrine");
	
# 	if ($pattern->isa('RDF::Query::Algebra::BasicGraphPattern') and not(scalar(@{$query->get_computed_statement_generators}))) {
# 		# call fixup on the triples so that they get converted to bridge-native objects
# 		my @triples		= map { $_->fixup( $query, $self, $base, $ns ) } $pattern->triples;
# 		my $tpattern	= RDF::Trine::Pattern->new( @triples );
# 		return RDF::Query::Model::RDFTrine::BasicGraphPattern->new( $tpattern, $pattern );
# 	} elsif ($pattern->isa('RDF::Query::Algebra::Filter')) {
	if ($pattern->isa('RDF::Query::Algebra::Filter')) {
		my $filter	= $pattern;
		my $ggp	= $filter->pattern;
		if ($ggp->isa('RDF::Query::Algebra::GroupGraphPattern')) {
			$l->debug("pattern is a ggp");
			my @patterns	= $ggp->patterns;
			if (scalar(@patterns) == 1 and $patterns[0]->isa('RDF::Query::Algebra::BasicGraphPattern')) {
				$l->debug("'-> pattern is a bgp");
				my $bgp	= $patterns[0];
				my $compiled;
				try {
					$self->model->_store->_sql_for_pattern( $filter );
					$compiled	= RDF::Query::Model::RDFTrine::Filter->new( $filter );
					$l->debug("    '-> filter can be compiled to RDF::Trine");
					$l->debug("        '-> " . Dumper($compiled));
				} otherwise {
					$l->debug("    '-> filter CANNOT be compiled to RDF::Trine");
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

=item C<< cost_naive ( $bgp, $context ) >>

=cut

sub cost_naive {
	my $self		= shift;
	my $costmodel	= shift;
	my $pattern		= shift;
	my $context		= shift;
	if ($pattern->isa('RDF::Query::Model::RDFTrine::BasicGraphPattern')) {
		# XXX hacked constant. this should do something more like ARQ's naive variable counting cost computation.
		my $card	= $self->cardinality_naive( $costmodel, $pattern, $context );
		return $card;
	}
	return;
}

=item C<< cardinality_naive ( $bgp, $context ) >>

=cut

sub cardinality_naive {
	my $self		= shift;
	my $costmodel	= shift;
	my $pattern		= shift;
	my $context		= shift;
	if ($pattern->isa('RDF::Query::Model::RDFTrine::BasicGraphPattern')) {
		# XXX hacked constant. this should do something more like ARQ's naive variable counting cost computation.
		my @t		= $pattern->triples;
		my $size	= 0.5 * $costmodel->_size;
		return $size ** scalar(@t);
	}
	return;
}

=item C<< generate_plans ( $algebra, $context ) >>

=cut

sub generate_plans {
	my $self	= shift;
	my $class	= ref($self) || $self;
	my $algebra	= shift;
	my $context	= shift;
	my %args	= @_;
	my $model	= $context->model;
	my $query	= $context->query;
	
	if (blessed($query) and $query->{force_no_optimization}) {
		return;
	}
	
	if ($algebra->isa('RDF::Query::Algebra::BasicGraphPattern')) {
		if (not($query) or not(scalar(@{$query->get_computed_statement_generators}))) {
			my @triples	= map { $_->distinguish_bnode_variables } $algebra->triples;
			return RDF::Query::Model::RDFTrine::BasicGraphPattern->new( @triples );
		}
	}
	return;
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
