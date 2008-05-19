# RDF::Query::Algebra::Service
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Service - Algebra class for SERVICE (federation) patterns

=cut

package RDF::Query::Algebra::Service;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

use URI::Escape;
use MIME::Base64;
use Data::Dumper;
use RDF::Query::Error;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION, $debug, $BLOOM_FILTER_ERROR_RATE);
BEGIN {
	$debug		= 0;
	$BLOOM_FILTER_ERROR_RATE	= 0.1;
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $endpoint, $pattern )>

Returns a new Service structure.

=cut

sub new {
	my $class		= shift;
	my $endpoint	= shift;
	my $pattern		= shift;
	return bless( [ 'SERVICE', $endpoint, $pattern ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->endpoint, $self->pattern);
}

=item C<< endpoint >>

Returns the endpoint resource of the named graph expression.

=cut

sub endpoint {
	my $self	= shift;
	if (@_) {
		my $endpoint	= shift;
		$self->[1]	= $endpoint;
	}
	my $endpoint	= $self->[1];
	return $endpoint;
}

=item C<< pattern >>

Returns the graph pattern of the named graph expression.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		my $pattern	= shift;
		$self->[2]	= $pattern;
	}
	return $self->[2];
}

=item C<< add_bloom ( $variable, $filter ) >>

Adds a FILTER to the enclosed GroupGraphPattern to restrict values of the named
C<< $variable >> to the values encoded in the C<< $filter >> (a
L<Bloom::Filter|Bloom::Filter> object).

=cut

sub add_bloom {
	my $self	= shift;
	my $class	= ref($self);
	my $var		= shift;
	my $bloom	= shift;
	
	unless (blessed($var)) {
		$var	= RDF::Query::Node::Variable->new( $var );
	}
	
	my $pattern	= $self->pattern;
	my $iri		= RDF::Query::Node::Resource->new('http://kasei.us/code/rdf-query/functions/bloom');
	warn "Adding a bloom filter (with " . $bloom->key_count . " items) function to a remote query" if ($debug);
	my $frozen	= $bloom->freeze;
	my $literal	= RDF::Query::Node::Literal->new( $frozen );
	my $expr	= RDF::Query::Expression::Function->new( $iri, $var, $literal );
	my $filter	= RDF::Query::Algebra::Filter->new( $expr, $pattern );
	return $class->new( $self->endpoint, $filter );
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(service %s %s)',
		$self->endpoint->sse( $context ),
		$self->pattern->sse( $context )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $string	= sprintf(
		"SERVICE %s %s",
		$self->endpoint->as_sparql( $context, $indent ),
		$self->pattern->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SERVICE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @list	= $self->pattern->referenced_variables;
	return @list;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return uniq(
		map { $_->name } grep { $_->isa('RDF::Query::Node::Variable') } ($self->graph),
		$self->pattern->definite_variables,
	);
}


=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	
	my $pattern	= $self->pattern->qualify_uris( $ns, $base );
	my $endpoint	= $self->endpoint;
	my $uri	= $endpoint->uri;
	return $class->new( $endpoint, $pattern );
}


=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		my $endpoint	= ($self->endpoint->isa('RDF::Query::Node'))
					? $bridge->as_native( $self->endpoint )
					: $self->endpoint->fixup( $query, $bridge, $base, $ns );
		my $fpattern	= $self->pattern->fixup( $query, $bridge, $base, $ns );
		return $class->new( $endpoint, $fpattern );
	}
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $outer_ctx	= shift;
	my %args		= @_;
	
	if ($outer_ctx) {
		throw RDF::Query::Error::QueryPatternError ( -text => "Can't use nested SERVICE graphs" );
	}

	my $endpoint	= $self->endpoint;
	if (my $l = $query->logger) {
		$l->push_value( service_endpoints => $endpoint->uri_value );
	}
	
	my %ns			= (%{ $query->{parsed}{namespaces} });
	my $trial		= 'k';
	$trial++ while (exists($ns{ $trial }));
	$ns{ $trial }	= 'http://kasei.us/code/rdf-query/functions/';
	
	my $sparql		= join("\n",
						(map { sprintf("PREFIX %s: <%s>", $_, $ns{$_}) } (keys %ns)),
						sprintf("SELECT DISTINCT * WHERE %s", $self->pattern->as_sparql({namespaces => \%ns}, ''))
					);
	my $url			= $endpoint->uri_value . '?query=' . uri_escape($sparql);
	
	warn "SERVICE REQUEST $endpoint:\n$sparql\n" if ($debug);
	if ($ENV{RDFQUERY_THROW_ON_SERVICE}) {
		warn "SERVICE REQUEST $endpoint:{{{\n$sparql\n}}}\n";
		warn "QUERY LENGTH: " . length($sparql) . "\n";
		warn "QUERY URL: $url\n";
		throw RDF::Query::Error::RequestedInterruptError -text => "Won't execute SERVICE block. Unset RDFQUERY_THROW_ON_SERVICE to continue.";
	}
	
	my $ua			= $query->useragent;
	
	
	# we jump through some hoops here to defer the actual execution unti the first
	# result is pulled from the stream. this has a slight speed hit in general,
	# but will have a huge benefit when, for example, two service calls are
	# concatenated with a union.
	my $stream;
	my $extra		= {};
	my @vars		= $self->pattern->referenced_variables;
	my $results		= RDF::Trine::Iterator::Bindings->new( sub {
		unless (defined $stream) {
			my $resp		= $ua->get( $url );
			unless ($resp->is_success) {
				throw RDF::Query::Error -text => "SERVICE query couldn't get remote content: " . $resp->status_line;
			}
			my $content	= $resp->content;
			$stream		= RDF::Trine::Iterator->from_string( $content );
			if (my $e = $stream->extra_result_data) {
				%$extra	= %$e;
			}
		}
		
		return $stream->next;
	}, \@vars, extra_result_data => $extra );
	
	my $cast		= smap {
						my $bindings	= $_;
						return undef unless ($bindings);
						my %cast	= map {
										$_ => RDF::Query::Model::RDFTrine::_cast_to_local( $bindings->{ $_ } )
									} (keys %$bindings);
						return \%cast;
					} $results;
	return $cast;
}

=item C<< bloom_filter_for_iterator ( $query, $bridge, $bound, $iterator, $variable, $error ) >>

Returns a Bloom::Filter object containing the Resource and Literal
values that are bound to $variable in the $iterator's data.

=cut

sub bloom_filter_for_iterator {
	my $class	= shift;
	my $query	= shift;
	my $bridge	= shift;
	my $bound	= shift;
	my $iter	= shift;
	my $var		= shift;
	my $error	= shift;
	
	my $name	= blessed($var) ? $var->name : $var;
	
	my @names;
	my %paths;
	my $node_count	= 0;
	while (my $result = $iter->next) {
		$node_count++;
		my $node	= $result->{ $name };
		push(@names, $class->_names_for_node( $node, $query, $bridge, $bound, \%paths, 0 ));
	}

	my $count	= scalar(@names);
	my $filter	= Bloom::Filter->new( capacity => $count, error_rate => $error );
	if ($debug) {
		warn $_ for (@names);
	}
	$filter->add( $_ ) for (@names);
	
	if ($debug) {
		warn "$node_count total nodes considered\n";
		warn "Bloom filter has $count total items\n";
		my @paths	= keys %paths;
		warn "PATHS:\n" . join("\n", @paths) . "\n";
	}
	$iter->reset;
	return $filter;
}

sub _names_for_node {
	my $class	= shift;
	my $node	= shift;
	my $query	= shift;
	my $bridge	= shift;
	my $bound	= shift;
	my $paths	= shift;
	my $depth	= shift || 0;
	my $pre		= shift || '';
	my $seen	= shift || {};
	return if ($depth > 2);
	
	warn "  " x $depth . "name for node " . $node->as_string . "...\n" if ($debug);
	
	my @names;
	my $parser	= RDF::Query::Parser::SPARQL->new();
	unless ($node->isa('RDF::Trine::Node::Literal')) {
		{
			our $sa		||= $parser->parse_pattern( '{ ?n <http://www.w3.org/2002/07/owl#sameAs> ?o }' );
			my $iter	= $sa->execute( $query, $bridge, { n => $node } );
			
			while (my $row = $iter->next) {
				my ($n, $o)	= @{ $row }{qw(n o)};
				push(@names, $class->_names_for_node( $o, $query, $bridge, $bound, $paths, $depth + 1, $pre . '=' ));
			}
		}
		
		{
			our $fp		||= $parser->parse_pattern( '{ ?o ?p ?n . ?p a <http://www.w3.org/2002/07/owl#FunctionalProperty> }' );
			my $iter	= $fp->execute( $query, $bridge, { n => $node } );
			
			while (my $row = $iter->next) {
				my ($p, $o)	= @{ $row }{qw(p o)};
				push(@names, $class->_names_for_node( $o, $query, $bridge, $bound, $paths, $depth + 1, $pre . '^' . $p->sse ));
			}
		}
		
		{
			our $ifp	||= $parser->parse_pattern( '{ ?n ?p ?o . ?p a <http://www.w3.org/2002/07/owl#InverseFunctionalProperty> }' );
			my $iter	= $ifp->execute( $query, $bridge, { n => $node } );
			
			while (my $row = $iter->next) {
				my ($p, $o)	= @{ $row }{qw(p o)};
				push(@names, $class->_names_for_node( $o, $query, $bridge, $bound, $paths, $depth + 1, $pre . '!' . $p->sse ));
			}
		}
	}
	
	unless ($node->isa('RDF::Trine::Node::Blank')) {
		my $string	= $pre . $node->as_string;
		$paths->{ $pre }++;
		push(@names, $string);
	}
	warn "  " x $depth . "-> " . join(', ', @names) . "\n" if ($debug);
	return @names;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
