# RDF::Query::Plan::Service
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::Service - Executable query plan for remote SPARQL queries.

=head1 VERSION

This document describes RDF::Query::Plan::Service version 2.910.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Plan> class.

=over 4

=cut

package RDF::Query::Plan::Service;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Data::Dumper;
use Scalar::Util qw(blessed refaddr);
use Storable qw(store_fd fd_retrieve);
use URI::Escape;

use RDF::Query::Error qw(:try);
use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION		= '2.910';
}

######################################################################

=item C<< new ( $endpoint, $plan, $silent, $sparql, [ \%logging_keys ] ) >>

Returns a new SERVICE (remote endpoint call) query plan object. C<<$endpoint>>
is the URL of the endpoint (as a node object). C<<$plan>> is the query plan
representing the query to be sent to the remote endpoint (needed for cost
estimates). C<<$sparql>> is the serialized SPARQL query to be sent to the remote
endpoint. Finally, if present, C<<%logging_keys>> is a HASH containing the keys
to use in logging the execution of this plan. Valid HASH keys are:

 * bf - The bound/free string representing C<<$plan>>

=cut

sub new {
	my $class		= shift;
	my $endpoint	= shift;
	my $plan		= shift;
	my $silent		= shift;
	my $sparql		= shift;
	unless ($sparql) {
		throw RDF::Query::Error::MethodInvocationError -text => "SERVICE plan constructor requires a serialized SPARQL query argument";
	}
	my $keys	= {};
	my $self;
	if ($endpoint->isa('RDF::Query::Node::Variable')) {
		my $lhs		= shift;
		Carp::confess "no lhs to binary SERVICE plan" unless ($lhs);
		$self	= $class->SUPER::new( $endpoint, $plan, $silent, $sparql, $lhs );
	} else {
		$self	= $class->SUPER::new( $endpoint, $plan, $silent, $sparql );
	}
	$self->[0]{referenced_variables}	= [ $plan->referenced_variables ];
	$self->[0]{logging_keys}	= $keys;
# 	if (@_) {
# 		# extra args (like the bound/free stuff for logging
# 		my %args	= @_;
# 		@{ $self->[0] }{ keys %args }	= values %args;
# 	}
	return $self;
}

=item C<< new_from_plan ( $endpoint, $plan, $context ) >>

Returns a new SERVICE query plan object. C<<$endpoint>> is the URL of the endpoint
(as a string). C<<$plan>> is the query plan representing the query to be sent to
the remote endpoint. The exact SPARQL serialization that will be used is obtained
by getting the originating RDF::Query::Algebra object from C<<$plan>>, and serializing
it (with the aid of the RDF::Query::ExecutionContext object C<<$context>>).

=cut

sub new_from_plan {
	my $class	= shift;
	my $url		= shift;
	my $plan	= shift;
	my $context	= shift;
	my $pattern	= $plan->label( 'algebra' );
	unless ($pattern->isa('RDF::Query::Algebra::GroupGraphPattern')) {
		$pattern	= RDF::Query::Algebra::GroupGraphPattern->new( $pattern );
	}
	my $ns		= $context->ns;
	my $sparql	= join("\n",
						(map { sprintf("PREFIX %s: <%s>", ($_ eq '__DEFAULT__' ? '' : $_), $ns->{$_}) } (keys %$ns)),
						sprintf("SELECT * WHERE %s", $pattern->as_sparql({namespaces => $ns}, ''))
					);
	my $service	= $class->new( $url, $plan, $sparql, @_ );
	return $service;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	$self->[0]{delegate}	= $context->delegate;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "SERVICE plan can't be executed while already open";
	}
	my $l			= Log::Log4perl->get_logger("rdf.query.plan.service");
	my $endpoint	= $self->endpoint;
	
	my $bound		= $context->bound || {};
	my $sparql		= $self->sparql( $bound );
	my $query		= $context->query;
	
	if ($self->lhs) {
		$self->lhs->execute( $context );
		$self->[0]{context}	= $context;
		$self->[0]{'open'}	= 1;
		$self->[0]{'count'}	= 0;
		$self->[0]{logger}	= $context->logger;
		$self->state( $self->OPEN );
	} else {
		{
			$l->debug('SERVICE execute');
			my $printable	= $sparql;
			$l->debug("SERVICE <$endpoint> pattern: $printable");
		}
		my $iter	= $self->_get_iterator( $context, $endpoint->uri_value, $sparql );
		if ($iter) {
	# 		$self->[0]{args}	= $args;
	# 		$self->[0]{fh}		= $fh;
	# 		$self->[0]{'write'}	= $write;
			$self->[0]{iter}	= $iter;
			$self->[0]{'open'}	= 1;
			$self->[0]{'count'}	= 0;
			$self->[0]{logger}	= $context->logger;
			if (my $log = $self->[0]{logger}) {
				$log->push_value( service_endpoints => $endpoint );
			}
			$self->state( $self->OPEN );
		} else {
			warn "no iterator in execute()";
		}
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open SERVICE";
	}
	return undef unless ($self->[0]{'open'});
	if ($self->lhs) {
		while (1) {
			if ($self->[0]{iter_stash}) {
				while (my $row = $self->[0]{iter_stash}->next) {
# 					warn "got service RHS row: $row\n";
					my $lhs		= $self->[0]{lhs_row};
# 					warn "joining:\n\t$row\n\t$lhs\n";
					if (my $j = $row->join( $lhs )) {
						return $j;
					}
				}
				delete $self->[0]{iter_stash};
			}
			my $lrow	= $self->lhs->next;
			unless ($lrow) {
# 				warn "reached end of service LHS iterator\n";
				delete $self->[0]{lhs_row};
				return undef;
			}
# 			warn "got service LHS row: $lrow\n";
			$self->[0]{lhs_row}	= $lrow;
			my $endpoint	= $lrow->{ $self->endpoint->name };
			unless (blessed($endpoint) and $endpoint->isa('RDF::Query::Node::Resource')) {
				throw RDF::Query::Error::ExecutionError -text => "Endpoint variable bound to non-IRI";
			}
			my $context	= $self->[0]{context};
			my $bound	= $context->bound || {};
			my $sparql	= $self->sparql( $bound );
			my $plan	= $RDF::Query::Plan::PLAN_CLASSES{'service'}->new( $endpoint, $self->pattern, $self->silent, $sparql );
# 			warn $plan;
			my $iter	= $plan->execute( $context );
			return undef unless ($iter);
			$self->[0]{iter_stash}	= $iter;
		}
	} else {
		my $iter	= $self->[0]{iter};
		my $result	= $iter->next;
		return undef unless $result;
		$self->[0]{'count'}++;
		my $row	= RDF::Query::VariableBindings->new( $result );
		$row->label( origin => [ $self->endpoint ] );
		if (my $d = $self->delegate) {
			$d->log_result( $self, $row );
		}
		return $row;
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open SERVICE";
	}
	delete $self->[0]{args};
	if (my $log = delete $self->[0]{logger}) {
		my $endpoint	= $self->endpoint;
		my $sparql		= $self->sparql;
		my $count		= $self->[0]{count};
		$log->push_key_value( 'cardinality-service-' . $endpoint, $sparql, $count );
		if (my $bf = $self->logging_keys->{ 'bf' }) {
			$log->push_key_value( 'cardinality-bf-service-' . $endpoint, $bf, $count );
		}
	}
	delete $self->[0]{count};
	my $fh	= delete $self->[0]{fh};
# 	1 while (<$fh>);
# 	delete $self->[0]{'write'};
# 	delete $self->[0]{'open'};
	$self->SUPER::close();
}

sub _get_iterator {
	my $self		= shift;
	my $context		= shift;
	my $endpoint	= shift;
	my $sparql		= shift;
	my $url			= $endpoint . '?query=' . uri_escape($sparql);
	my $l			= Log::Log4perl->get_logger("rdf.query.plan.service");
	$l->trace( 'SERVICE URL: ' . $url );
	my $query		= $context->query;
	
	my $handler	= RDF::Trine::Iterator::SAXHandler->new();
	my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
	
	
	my $ua			= ($query)
					? $query->useragent
					: do {
						my $u = LWP::UserAgent->new( agent => "RDF::Query/${RDF::Query::VERSION}" );
						$u->default_headers->push_header( 'Accept' => "application/sparql-results+xml;q=0.9,application/rdf+xml;q=0.5,text/turtle;q=0.7,text/xml" );
						$u;
					};
	
	my $req			= HTTP::Request->new('GET', $url );
	my $response	= $self->_request( $ua, $req );
	if (blessed($response) and $response->is_success) {
		$p->parse_string( $response->content );
		return $handler->iterator;
	} elsif ($self->silent) {
		my $v		= RDF::Query::VariableBindings->new( {} );
		my $iter	= RDF::Trine::Iterator::Bindings->new( [ $v ] );
		return $iter;
	} else {
		my $status		= $response->status_line;
		my $sparql		= $self->sparql;
# 		warn "url: $url\n";
		unless ($self->silent) {
			throw RDF::Query::Error::ExecutionError -text => "*** error making remote SPARQL call to endpoint $endpoint ($status) while making service call for query: $sparql";
		}
	}
}

sub _request {
	my $self	= shift;
	my $ua		= shift;
	my $req		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.plan.service");
	
	if ($ENV{RDFQUERY_THROW_ON_SERVICE}) {
		if ($self->silent) {
			return;
		} else {
			throw RDF::Query::Error::RequestedInterruptError -text => "Won't execute SERVICE block. Unset RDFQUERY_THROW_ON_SERVICE to continue.";
		}
	}
	
	my $response	= $ua->request( $req );
	return $response;
}

# sub _get_and_parse_url {
# 	my $self	= shift;
# 	my $context	= shift;
# 	my $url		= shift;
# 	my $fh		= shift;
# 	my $pid		= shift;
# 	my $query	= $context->query;
# 
# 	eval "
# 		require XML::SAX::Expat;
# 		require XML::SAX::Expat::Incremental;
# 	";
# 	if ($@) {
# 		die $@;
# 	}
# 	local($XML::SAX::ParserPackage)	= 'XML::SAX::Expat::Incremental';
# 	my $handler	= RDF::Trine::Iterator::SAXHandler->new();
# 	my $p	= XML::SAX::Expat::Incremental->new( Handler => $handler );
# 	$p->parse_start;
# 	
# 	my $has_head	= 0;
# 	my $callback	= sub {
# 		my $content	= shift;
# 		my $resp	= shift;
# 		my $proto	= shift;
# 		unless ($resp->is_success) {
# 			throw RDF::Query::Error -text => "SERVICE query couldn't get remote content: " . $resp->status_line;
# 		}
# 		$p->parse_more( $content );
# 		
# 		if (not($has_head) and $handler->has_head) {
# 			my @args	= $handler->iterator_args;
# 			if (exists( $args[2]{Handler} )) {
# 				delete $args[2]{Handler};
# 			}
# 			$has_head	= 1;
# 			store_fd \@args, $fh or die "PID $pid can't store!\n";
# 		}
# 		
# 		while (my $data = $handler->pull_result) {
# 			store_fd $data, $fh or die "PID $pid can't store!\n";
# 		}
# 	};
# 	my $ua			= ($query)
# 					? $query->useragent
# 					: do {
# 						my $u = LWP::UserAgent->new( agent => "RDF::Query/${RDF::Query::VERSION}" );
# 						$u->default_headers->push_header( 'Accept' => "application/sparql-results+xml;q=0.9,application/rdf+xml;q=0.5,text/turtle;q=0.7,text/xml" );
# 						$u;
# 					};
# 
# 	$ua->get( $url, ':content_cb' => $callback );
# 	store_fd \undef, $fh or die "can't store end-of-stream";
# }

=item C<< endpoint >>

=cut

sub endpoint {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	my $e		= $self->[1];
	return $e;
}

=item C<< sparql >>

Returns the SPARQL query (as a string) that will be sent to the remote endpoint.

=cut

sub sparql {
	my $self	= shift;
	my $sparql	= $self->[4];
	if (ref($sparql)) {
		$sparql	= $sparql->( @_ );
	}
	return $sparql;
}

=item C<< lhs >>

=cut

sub lhs {
	my $self	= shift;
	my $lhs		= $self->[5];
	return $lhs;
}

=item C<< silent >>

Returns a boolean value indicating whether the service plan will ignore errors.

=cut

sub silent {
	my $self	= shift;
	return $self->[3];
}

=item C<< pattern >>

Returns the query plan that will be used in the remote service call.

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	my $self	= shift;
	# XXX this could be set at construction time, if we want to trust the remote
	# XXX endpoint to return DISTINCT results (when appropriate).
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	my $self	= shift;
	# XXX this could be set at construction time, if we want to trust the remote
	# XXX endpoint to return ORDERED results (when appropriate).
	return 0;
}

=item C<< plan_node_name >>

Returns the string name of this plan node, suitable for use in serialization.

=cut

sub plan_node_name {
	return 'service';
}

=item C<< plan_prototype >>

Returns a list of scalar identifiers for the type of the content (children)
nodes of this plan node. See L<RDF::Query::Plan> for a list of the allowable
identifiers.

=cut

sub plan_prototype {
	my $self	= shift;
	return qw(u s);
}

=item C<< plan_node_data >>

Returns the data for this plan node that corresponds to the values described by
the signature returned by C<< plan_prototype >>.

=cut

sub plan_node_data {
	my $self	= shift;
	my $expr	= $self->[2];
	return ($self->endpoint, $self->sparql);
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	$g->add_node( "$self", label => "Service (" . $self->endpoint->value . ")" . $self->graph_labels );
	$g->add_node( "${self}-sparql", label => $self->sparql );
	$g->add_edge( "$self" => "${self}-sparql" );
	return "$self";
}

=item C<< explain >>

Returns a string serialization of the query plan appropriate for display
on the command line.

=cut

sub explain {
	my $self	= shift;
	my ($s, $count)	= ('  ', 0);
	if (@_) {
		$s		= shift;
		$count	= shift;
	}
	my $indent	= '' . ($s x $count);
	my $type	= $self->plan_node_name;
	my $sparql	= $self->sparql;
	$sparql		=~ s/\n/\n${indent}${s}${s}/g;
	my $string	= sprintf("%s%s (0x%x)\n", $indent, $type, refaddr($self))
				. "${indent}${s}" . $self->endpoint->as_string . "\n"
				. "${indent}${s}${sparql}\n";
	return $string;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
