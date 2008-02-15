package RDF::Query::Model::RDFTrine;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Model);

use Carp qw(carp croak confess);

use RDF::Query::Error (':try');
use File::Spec;
use RDF::Trine::Parser;
use RDF::Trine::Store::DBI;
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use LWP::Simple qw(get);
use Encode;

use RDF::Trine::Iterator;

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
		$model	= RDF::Trine::Store::DBI->temporary_store();
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
	
	my $content		= get( $uri );
	$self->add_string( $content, $uri, $named, $format );
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
	my $format	= shift || 'guess';
	
	if (not $named) {
		$self->ignore_contexts();
	}
	
	$self->set_context( $base );
	my $parser	= RDF::Trine::Parser->new('turtle');
	try {
		$parser->parse_into_model( $base, $data, $self );
	} catch RDF::Trine::Parser::Error with {
		require RDF::Redland;
		my $uri		= RDF::Redland::URI->new( $base );
		my $parser	= RDF::Redland::Parser->new($format);
		my $stream	= $parser->parse_string_as_stream($data, $uri);
		while ($stream and !$stream->end) {
			my $statement	= $stream->current;
			my $stmt		= RDF::Query::Algebra::Triple->from_redland( $statement );
			$self->add_statement( $stmt );
			$stream->next;
		}
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
	if ($context and $context->isa('RDF::Trine::Node::Resource')) {
		if ($self->equals( $context, $self->get_context)) {
			Carp::cluck( Dumper(@triple, $context) );	# XXX
		} else {
			return RDF::Trine::Iterator::Graph->new( [], bridge => $self );
		}
	}
	
	my $model	= $self->{'model'};
	my $stream	= $model->get_statements( map { $self->is_node($_) ? $_ : $self->new_variable() } @triple );
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

=item C<get_context ($stream)>

Returns the context node of the last statement retrieved from the specified
C<$stream>. The stream object, in turn, calls the closure (that was passed to
the stream constructor in C<get_statements>) with the argument 'context'.

=cut

sub get_context {
	my $self	= shift;
	if (exists($self->{context})) {
		return $self->new_resource( $self->{context} );
	} else {
		return;
	}
}

=item C<< set_context ( $url ) >>

Sets the context of triples in this model.

=cut

sub set_context {
	my $self	= shift;
	my $name	= shift;
	if (exists($self->{context}) and not($self->{ignore_contexts})) {
		Carp::confess "RDF::Trine::Store::DBI models can only represent a single context" unless ($self->{context} eq $name);
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
	return 1 if ($feature eq 'xml');
	return 0;
}

=item C<< unify_bgp ( $bgp, \%bound, $context, %args ) >>

Called with a RDF::Query::Algebra::BasicGraphPattern for execution all-at-once
instead of making individual execute() calls on all the constituent
RDF::Query::Algebra::Triple patterns and joining them.

C<< $context >> is currently ignored as the calling code in
RDF::Query::Algebra::BasicGraphPattern::execute is currently ensuring that
we do the right thing w.r.t. named graphs. Should probably change in the future
as named graph support is moved into the model bridge code.

=cut

sub unify_bgp {
	my $self	= shift;
	my $bgp		= shift;
	my $bound	= shift;
	my $context	= shift;
	my %args	= @_;
	
	if ($context and $context->isa('RDF::Trine::Node::Resource')) {
		unless ($self->equals( $context, $self->get_context)) {
			return RDF::Trine::Iterator::Bindings->new( [], [], bridge => $self );
		}
	}
	
	my $pattern	= $bgp->clone;
	my $model	= $self->model;
	foreach my $triple ($pattern->triples) {
		foreach my $method (qw(subject predicate object)) {
			my $node	= $triple->$method();
			if ($node->isa('RDF::Trine::Node::Blank')) {
				my $var	= RDF::Trine::Node::Variable->new( '__' . $node->blank_identifier );
				$triple->$method( $var );
			}
		}
	}
	
	# BINDING has to happen after the blank->var substitution above, because
	# we might have a bound bnode.
	$pattern	= $pattern->bind_variables( $bound );
	
	my @args;
	if (my $o = $args{ orderby }) {
		push( @args, orderby => [ map { $_->[1]->name => $_->[0] } grep { blessed($_->[1]) and $_->[1]->isa('RDF::Trine::Node::Variable') } @$o ] );
	}
	
	return $model->get_pattern( $pattern, undef, @args );
}

1;

__END__

=back

=cut
