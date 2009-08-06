# RDF::Query::Model::RDFCore
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model::RDFCore - An RDF::Query::Model backend for interfacing with an RDF::Core model.

=head1 VERSION

This document describes RDF::Query::Model::RDFCore version 2.200, released 6 August 2009.

=cut

package RDF::Query::Model::RDFCore;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Model);

use Carp qw(carp croak);

use Log::Log4perl;
use Data::Dumper;
use File::Spec;
use File::Temp qw(tempfile);
use LWP::UserAgent;
use RDF::Core::Model;
use RDF::Core::Query;
use RDF::Core::Model::Parser;
use RDF::Core::Storage::Memory;
use RDF::Core::NodeFactory;
use RDF::Core::Model::Serializer;
use Scalar::Util qw(blessed);

use RDF::Trine::Iterator;
use RDF::Trine::Statement::Quad;

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
	my $self	= shift;
	
	return {
		class		=> __PACKAGE__,
		model		=> 'RDF::Core::Model',
		store		=> 'RDF::Core::Storage',
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
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Query/${RDF::Query::VERSION}" );
	$ua->default_headers->push_header( 'Accept' => "application/rdf+xml;q=0.5, text/turtle;q=0.7, text/xml" );
	
	my $resp	= $ua->get( $url );
	unless ($resp->is_success) {
		warn "No content available from $url: " . $resp->status_line;
		return;
	}
	my $rdf	= $resp->content;
	$self->add_string( $rdf, $url, $named );
}

=item C<add_string ( $data, $base_uri, $named, $format )>

Addsd the contents of C<$data> to the model. If C<$named> is true,
the data is added to the model using C<$base_uri> as the named context.

=cut

sub add_string {
	my $self	= shift;
	my $data	= shift;
	my $uri		= shift;
	my $named	= shift;
	
	my $model	= ($named)
				? $self->_named_graph_models( $uri )
				: $self->model;
	
	our $USE_RAPPER;
	if ($USE_RAPPER) {
		if ($data !~ m/<rdf:RDF/ms) {
			my ($fh, $filename) = tempfile();
			print $fh $data;
			close($fh);
			$data	= do {
								open(my $fh, '-|', "rapper -q -i turtle -o rdfxml $filename");
								local($/)	= undef;
								my $data	= <$fh>;
								my $c		= $self->{counter}++;
								$data		=~ s/nodeID="([^"]+)"/nodeID="r${c}r$1"/smg;
								$data;
							};
			unlink($filename);
		}
	}
	
	my %options = (
				Model		=> $model,
				Source		=> $data,
				SourceType	=> 'string',
				BNodePrefix	=> "genid" . $self->{counter}++ . 'r',
			);
	$options{ BaseURI }	= $uri if ($uri);
	my $parser	= new RDF::Core::Model::Parser (%options);
	$parser->parse;
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
	
	for my $i (0, 1) {
		my $node	= $triple[ $i ];
		if (blessed($node) and $node->isa('RDF::Trine::Node::Literal')) {
			# we have to check this manually, because (as of 2008.7.29) RDF::Core
			# will die if we try to get statements with a literal in the subject
			# or predicate position.
			return RDF::Trine::Iterator::Graph->new( [] );
		}
	}
	
	@triple		= map { _cast_to_rdfcore( $_ ) } @triple;
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
			push(@nodes, _cast_to_local( $n ));
		}
		my $st	= RDF::Query::Algebra::Triple->new( @nodes );
		return $st;
	};
	
	return RDF::Trine::Iterator::Graph->new( $stream, bridge => $self );
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
	
	@triple		= map { _cast_to_rdfcore( $_ ) } @triple;
	
	if (not defined($context) or $context->isa('RDF::Trine::Node::Variable')) {
		my $nstream;
		my %models	= $self->_named_graph_models;
		foreach my $uri (keys %models) {
			my $c	= RDF::Query::Node::Resource->new( $uri );
			my $model	= $models{ $uri };
			my $enum	= $model->getStmts( @triple );
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
					push(@nodes, _cast_to_local( $n ));
				}
				my $st	= RDF::Query::Algebra::Quad->new( @nodes, $c );
				return $st;
			};
			
			my $iter	= RDF::Trine::Iterator::Graph->new( $stream, bridge => $self );
			if ($nstream) {
				$nstream	= $nstream->concat( $iter );
			} else {
				$nstream	= $iter;
			}
		}
		unless ($nstream) {
			$nstream	= RDF::Trine::Iterator::Graph->new([]);
		}
		return $nstream;
	} else {
		my $model	= $self->_named_graph_models( $context->uri_value );
		my $enum	= $model->getStmts( @triple );
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
				push(@nodes, _cast_to_local( $n ));
			}
			my $st	= RDF::Query::Algebra::Quad->new( @nodes, $context );
			return $st;
		};
		
		return RDF::Trine::Iterator::Graph->new( $stream, bridge => $self );
	}
}


sub _cast_to_rdfcore {
	my $node	= shift;
	return undef unless (blessed($node));
	if ($node->isa('RDF::Trine::Statement')) {
		my @nodes	= map { _cast_to_rdfcore( $_ ) } $node->nodes;
		return RDF::Core::Statement->new( @nodes );
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
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

sub _cast_to_local {
	my $node	= shift;
	return unless (blessed($node));
	if ($node->isLiteral) {
		my $lang	= $node->getLang;
		my $dt		= $node->getDatatype;
		return RDF::Query::Node::Literal->new( $node->getValue, $lang, $dt );
	} elsif ($node->isa('RDF::Core::Resource') and $node->getURI =~ /^_:/) {
		my $label	= $node->getLabel;
		$label		=~ s/^_://;
		return RDF::Query::Node::Blank->new( $label );
	} elsif ($node->isa('RDF::Core::Resource')) {
		return RDF::Query::Node::Resource->new( $node->getLabel );
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
	my $rstmt	= _cast_to_rdfcore( $stmt );
	$model->addStmt( $rstmt );
}

=item C<< remove_statement ( $statement ) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $stmt	= shift;
	my $model	= $self->model;
	my $rstmt	= _cast_to_rdfcore( $stmt );
	$model->removeStmt( $rstmt );
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

=item C<< debug >>

Prints debugging information about the model (including all statements in the
model) to STDERR.

=cut

sub debug {
	my $self	= shift;
	my $model	= shift || $self->model;
	my $l		= Log::Log4perl->get_logger("rdf.query.model.rdfcore");
	if ($l->is_debug) {
		my $stream	= $model->getStmts();
		$l->debug("------------------------------");
		my $statement	= $stream->getFirst;
		while (defined $statement) {
			$l->debug($statement->getLabel);
			$statement = $stream->getNext
		}
		$stream->close;
		$l->debug("------------------------------");
	}
}

sub _named_graph_models {
	my $self	= shift;
	if (@_) {
		my $graph	= shift;
		if ($self->{named_graphs}{$graph}) {
			return $self->{named_graphs}{$graph};
		} else {
			my $storage	= new RDF::Core::Storage::Memory;
			my $model	= new RDF::Core::Model (Storage => $storage);
			$self->{named_graphs}{$graph}	= $model;
			return $model;
		}
	} else {
		return %{ $self->{named_graphs} || {} };
	}
}

1;

__END__

=back

=cut

