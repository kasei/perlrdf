# RDF::Query::Model
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model - Model base class

=cut

package RDF::Query::Model;

use strict;
use warnings;
no warnings 'redefine';

use RDF::Query::Error qw(:try);

use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.003_01';
}

######################################################################

=head1 METHODS

=over 4

=item C<parsed>

Returns the query parse tree.

=cut

sub parsed {
	my $self	= shift;
	return $self->{parsed};
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
		my $node	= RDF::Query::Node::Resource->new( $uri );
		return $node;
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
	return RDF::Query::Node::Literal->new( $value, $lang, $type );
}

=item C<new_blank ( $identifier )>

Returns a new blank node object.

=cut

sub new_blank {
	my $self	= shift;
	my $name	= shift;
	return RDF::Query::Node::Blank->new( $name );
}

=item C<new_statement ( $s, $p, $o )>

Returns a new statement object.

=cut

sub new_statement {
	my $self	= shift;
	my ($s, $p, $o)	= @_;
	return RDF::Query::Algebra::Triple->new( $s, $p, $o );
}

=item C<new_variable ( $name )>

Returns a new variable object.

=cut

sub new_variable {
	my $self	= shift;
	unless (@_) {
		my $name	= '__rdfstoredbi_variable_' . $self->{_blank_id}++;
		push(@_, $name);
	}
	my $name	= shift;
	return RDF::Query::Node::Variable->new( $name );
}


=item C<< as_native ( $node, $base, \%namespaces ) >>

Returns bridge-native RDF node objects for the given node.

=cut

sub as_native {
	my $self	= shift;
	my $node	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	return unless (blessed($node) and $node->isa('RDF::Query::Node'));
	if ($node->isa('RDF::Query::Node::Resource')) {
		my $uri	= $node->uri_value;
		if (ref($uri) and reftype($uri) eq 'ARRAY') {
			$uri	= join('', $ns->{ $uri->[0] }, $uri->[1] );
		}
		return $self->new_resource( $uri, $base );
	} elsif ($node->isa('RDF::Query::Node::Literal')) {
		my $dt	= $node->literal_datatype;
		if (ref($dt) and reftype($dt) eq 'ARRAY') {
			$dt	= join('', $ns->{ $dt->[0] }, $dt->[1] );
		}
		return $self->new_literal( $node->literal_value, $node->literal_value_language, $dt );
	} elsif ($node->isa('RDF::Query::Node::Blank')) {
		return $node;
#		return RDF::Query::Node::Variable->new();
#		return $self->new_blank( $node->blank_identifier );
	} else {
		# keep variables as they are
		return $node;
	}
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

=item C<is_node ( $node )>

=item C<isa_node ( $node )>

Returns true if C<$node> is a node object for the current model.

=cut

sub isa_node {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Trine::Node'));
}

=item C<is_resource ( $node )>

=item C<isa_resource ( $node )>

Returns true if C<$node> is a resource object for the current model.

=cut

sub isa_resource {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Trine::Node::Resource'));
}

=item C<is_literal ( $node )>

=item C<isa_literal ( $node )>

Returns true if C<$node> is a literal object for the current model.

=cut

sub isa_literal {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Trine::Node::Literal'));
}

=item C<is_blank ( $node )>

=item C<isa_blank ( $node )>

Returns true if C<$node> is a blank node object for the current model.

=cut

sub isa_blank {
	my $self	= shift;
	my $node	= shift;
	return (blessed($node) and $node->isa('RDF::Trine::Node::Blank'));
}
no warnings 'once';
*RDF::Query::Model::is_node		= \&isa_node;
*RDF::Query::Model::is_resource	= \&isa_resource;
*RDF::Query::Model::is_literal		= \&isa_literal;
*RDF::Query::Model::is_blank		= \&isa_blank;


=item C<literal_value ( $node )>

Returns the string value of the literal object.

=cut

sub literal_value {
	my $self	= shift;
	my $node	= shift;
	return undef unless (blessed($node));
	return undef unless ($self->is_literal( $node ));
	if ($node->isa('DateTime')) {
		my $f	= DateTime::Format::W3CDTF->new;
		my $l	= $f->format_datetime( $node );
		return $l;
	} else {
		return $node->literal_value || '';
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
	return $node->uri_value;
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

=item C<< subject ( $statement ) >>

Returns the subject of the statement.

=cut

sub subject {
	my $self	= shift;
	my $st		= shift;
	return $st->subject;
}

=item C<< predicate ( $statement ) >>

Returns the predicate of the statement.

=cut

sub predicate {
	my $self	= shift;
	my $st		= shift;
	return $st->predicate;
}

=item C<< object ( $statement ) >>

Returns the object of the statement.

=cut

sub object {
	my $self	= shift;
	my $st		= shift;
	return $st->object;
}

# sub new;
# sub model;
# sub new_resource;
# sub new_literal;
# sub new_blank;
# sub new_statement;
# sub new_variable;
# sub isa_node;
# sub isa_resource;
# sub isa_literal;
# sub isa_blank;
# sub equals;
# sub as_string;
# sub literal_value;
# sub literal_datatype;
# sub literal_value_language;
# sub uri_value;
# sub blank_identifier;
# sub add_uri;
# sub add_string;
# sub statement_method_map;
# sub subject;
# sub predicate;
# sub object;
# sub get_statements;
# sub multi_get;
# sub add_statement;
# sub remove_statement;
# sub get_context;
# sub supports;
# sub node_count;
# sub model_as_stream;

=item C<< get_statements ( $subject, $predicate, $object ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	my $iter	= $self->_get_statements( $s, $p, $o );
	if (@_) {
		my $query	= shift;
		my $bound	= shift;
		if (my $extra_iter = $self->get_computed_statements( $s, $p, $o, $query, $bound )) {
			$iter	= $iter->concat( $extra_iter );
		}
	}
	return $iter;
}

=item C<< get_basic_graph_pattern ( $execution_context, @triples ) >>

Returns a stream object of all variable bindings matching the specified RDF::Trine::Statement objects.

=cut

sub get_basic_graph_pattern {
	my $self	= shift;
	my $context	= shift;
	my @triples	= @_;
	my $iter	= $self->_get_basic_graph_pattern( @triples );
	return $iter;
}

=item C<< get_computed_statements ( $subject, $predicate, $object, $query, \%bound ) >>

Returns a stream object of all computed statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_computed_statements {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	my $query	= shift;
	my $bound	= shift;
	my $iter;
	if (blessed($query)) {
		my $comps	= $query->get_computed_statement_generators;
		foreach my $c (@$comps) {
			my $new	= $c->( $query, $self, $bound, $s, $p, $o );
			if ($new and not($iter)) {
				$iter	= $new;
			} elsif ($new) {
				$iter	= $iter->concat( $new );
			}
		}
		return $iter;
	}
}

=item C<< get_named_statements ( $subject, $predicate, $object, $context ) >>

Returns a stream object of all statements matching the specified subject,
predicate, object and context. Any of the arguments may be undef to match
any value.

=cut

sub get_named_statements {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	my $c		= shift;
	my $iter	= $self->_get_named_statements( $s, $p, $o, $c );
	if (@_) {
		my $query	= shift;
		my $bound	= shift;
	}
	return $iter;
}



=item C<count_statements ($subject, $predicate, $object)>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	
	my @defs	= grep defined, @triple;
	my $model	= $self->{'model'};
	my $stream;
	
	my $iter	= $model->get_statements( @triple, $context );
	my $count	= 0;
	while (my $row = $iter->next) {
		$count++;
	}
	
	return $count;
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
	my $total	= $self->count_statements();
	my $count	= $self->count_statements( @_ );
	return 0 unless ($total);
	return $count / $total;
}

=item C<< fixup ( $pattern, $query, $base, \%namespaces ) >>

Called prior to query execution, if the underlying model can optimize
the execution of C<< $pattern >>, this method returns a optimized
RDF::Query::Algebra object to replace C<< $pattern >>. Otherwise, returns
C<< undef >> and the C<< fixup >> method of C<< $pattern >> will be used
instead.

=cut

sub fixup {
	return;
}

=item C<< debug >>

Prints debugging information about the model (including all statements in the
model) to STDERR.

=cut

sub debug {
	my $self	= shift;
	my $stream	= $self->get_statements( map { $self->new_variable($_) } qw(s p o) );
	my $nstream	= $self->get_named_statements( map { $self->new_variable($_) } qw(s p o c) );
	my $l		= Log::Log4perl->get_logger("rdf.query.model");
	$l->debug("DEFAULT GRAPH ------------------------------");
	while (my $st = $stream->next) {
		$l->debug($self->as_string( $st ));
	}
	$l->debug("NAMED GRAPH ------------------------------");
	while (my $st = $nstream->next) {
		$l->debug($self->as_string( $st ));
	}
	$l->debug("------------------------------");
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
