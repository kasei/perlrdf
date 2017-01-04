# RDF::Query::ServiceDescription
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::ServiceDescription - Class for describing federated query data sources.

=head1 VERSION

This document describes RDF::Query::ServiceDescription version 2.918.

=head1 METHODS

=over 4

=cut

package RDF::Query::ServiceDescription;

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

use strict;
use warnings;
no warnings 'redefine';

use URI::file;
use RDF::Trine::Iterator qw(smap swatch);
use Scalar::Util qw(blessed);
use LWP::UserAgent;
use Data::Dumper;

=item C<< new ( $service_uri, %data ) >>

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	my %data	= @_;
	unless ($data{capabilities}) {
		$data{capabilities}	= [ { type => RDF::Query::Node::Resource->new('http://kasei.us/2008/04/sparql#any_triple') } ];

	}
	my $data	= {
					url				=> $uri,
					label			=> "SPARQL Endpoint $uri",
					definitive		=> 0,
					%data,
				};
	my $self	= bless( $data, $class );
	return $self;
}

=item C<< new_from_uri ( $url ) >>

Creates a new service description object using the DARQ-style service description
data located at C<< $url >>.

=cut

sub new_from_uri {
	my $class	= shift;
	my $uri		= shift;
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Query/$RDF::Query::VERSION" );
	$ua->default_headers->push_header( 'Accept' => "application/rdf+xml;q=0.5,text/turtle;q=0.7,text/xml" );
	my $resp	= $ua->get( $uri );
	unless ($resp->is_success) {
		warn "No content available from $uri: " . $resp->status_line;
		return;
	}
	my $content	= $resp->content;
	
	my $store	= RDF::Trine::Store::DBI->temporary_store();
	my $model	= RDF::Trine::Model->new( $store );
	my $parser	= RDF::Trine::Parser->new('turtle');
	$parser->parse_into_model( $uri, $content, $model );
	return $class->new_with_model( $model );
}

=item C<< new_with_model ( $model ) >>

Creates a new service description object using the DARQ-style service description
data loaded in the supplied C<< $model >> object.

=cut

sub new_with_model {
	my $class	= shift;
	my $model	= shift;
	my ($label, $url, $triples, $definitive, @capabilities, @patterns);
	my $l		= Log::Log4perl->get_logger("rdf.query.servicedescription");
	my $infoquery	= RDF::Query->new( <<"END" );
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		PREFIX foaf: <http://xmlns.com/foaf/0.1/#>
		PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
		PREFIX sd: <http://darq.sf.net/dose/0.1#>
		SELECT ?label ?url ?size ?def
		WHERE {
			?s a sd:Service ;
				rdfs:label ?label ;
				sd:url ?url .
			OPTIONAL { ?s sd:totalTriples ?size . FILTER( ISLITERAL(?size) ) }
			OPTIONAL { ?s sd:isDefinitive ?def . FILTER( ISLITERAL(?def) ) }
			FILTER( ISLITERAL(?label) && ISURI(?url) ).
		}
		LIMIT 1
END
	($label, $url, $triples, my $def)	= $infoquery->get( $model );
	return undef unless (defined $label);
	$definitive	= (defined($def) ? ($def->literal_value eq 'true' ? 1 : 0) : 0);
	
	{
		my $capquery	= RDF::Query->new( <<"END" );
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX foaf: <http://xmlns.com/foaf/0.1/#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			PREFIX sd: <http://darq.sf.net/dose/0.1#>
			PREFIX sparql: <http://kasei.us/2008/04/sparql#>
			SELECT DISTINCT ?pred ?type ?sofilter ?ssel ?osel ?triples
			WHERE {
				[] a sd:Service ;
					sd:capability ?cap .
				{
					?cap sd:predicate ?pred .
				} UNION {
					?cap a ?type .
					FILTER(?type = sparql:any_triple)
				}
				OPTIONAL { ?cap sd:sofilter ?sofilter }
				OPTIONAL { ?cap sd:objectSelectivity ?osel }
				OPTIONAL { ?cap sd:subjectSelectivity ?ssel }
				OPTIONAL { ?cap sd:triples ?triples }
			}
END
		my $iter	= $capquery->execute( $model );
		while (my $row = $iter->next) {
			my ($p, $type, $f, $ss, $os, $t)	= @{ $row }{ qw(pred type sofilter ssel osel triples) };
			my $data						= ($p)
											? { pred => $p }
											: { type => $type };
			$data->{ object_selectivity }	= $os if (defined $os);
			$data->{ subject_selectivity }	= $ss if (defined $ss);
			$data->{ size }					= $t if (defined $t);
			if (defined $f) {
				my $base;
				my $parser	= RDF::Query::Parser::SPARQL->new();
				my $expr	= $parser->parse_expr( $f->literal_value, $base, {} );
				$data->{ sofilter }			= $expr;
			}
			push(@capabilities, $data);
		}
	}
	
	{
		my $var_id	= 1;
		my @statements;
		my %patterns;
		my %bnode_map;
		
		my $patterns	= $model->get_statements( undef, RDF::Trine::Node::Resource->new('http://kasei.us/2008/04/sparql#pattern'), undef );
		while (my $st = $patterns->next) {
			my $pattern	= $st->object;
			my @queue	= ($pattern);
			while (my $subj = shift(@queue)) {
				my $stream	= $model->get_statements( $subj, undef, undef );
				while (my $st = $stream->next) {
					push(@queue, $st->object);
					my @nodes	= ($subj, $st->predicate, $st->object);
					foreach my $i (0 .. $#nodes) {
						if ($nodes[$i]->isa('RDF::Query::Node::Blank')) {
							if (exists($bnode_map{ $nodes[$i]->as_string })) {
								$nodes[$i]	= $bnode_map{ $nodes[$i]->as_string };
							} else {
								$nodes[$i]	= $bnode_map{ $nodes[$i]->as_string }	= RDF::Query::Node::Variable->new('p' . $var_id++);
							}
						}
					}
					my $st	= RDF::Query::Algebra::Triple->new( @nodes );
					push(@{ $patterns{ $pattern->as_string } }, $st );
				}
			}
		}
		foreach my $k (keys %patterns) {
			my $bgp	= RDF::Query::Algebra::BasicGraphPattern->new( @{ $patterns{ $k } } );
			$l->debug("SERVICE BGP: " . $bgp->as_sparql({}, ''));
			push( @patterns, $bgp );
		}
	}
	
	my %data	= (
					label			=> (ref($label) ? $label->literal_value : ''),
					size			=> (ref($triples) ? $triples->literal_value : ''),
					definitive		=> $definitive,
					capabilities	=> \@capabilities,
					patterns		=> \@patterns,
				);
	return $class->new( $url->uri_value, %data );
}

=item C<< url >>

Returns the endpoint URL of the service.

=cut

sub url {
	my $self	= shift;
	return $self->{url};
}

=item C<< size >>

Returns the number of triples the service claims to have.

=cut

sub size {
	my $self	= shift;
	return $self->{size};
}

=item C<< label >>

Returns the label of the service.

=cut

sub label {
	my $self	= shift;
	return $self->{label};
}

=item C<< definitive >>

Returns true if the endpoint claims to have definitive information.

=cut

sub definitive {
	my $self	= shift;
	return $self->{definitive};
}

=item C<< capabilities >>

Returns an ARRAY reference of capabilities (as HASH references) of the service.
Each capability will contain information on size, selectivity, any subject-object
filter, and required predicate, with the following classes:

  $capability->{object_selectivity} # RDF::Trine::Node::Literal xsd:double
  $capability->{sofilter} # RDF::Query::Expression
  $capability->{size} # RDF::Trine::Node::Literal xsd:integer
  $capability->{pred} # RDF::Trine::Node::Resource

=cut

sub capabilities {
	my $self	= shift;
	return $self->{capabilities};
}

=item C<< patterns >>

Returns an ARRAY reference of RDF::Query::Algebra::BasicGraphPattern objects
representing common patterns used by the endpoint.

=cut

sub patterns {
	my $self	= shift;
	return $self->{patterns};
}

=item C<< computed_statement_generator >>

Returns a closure appropriate for passing to C<< RDF::Query->add_computed_statement_generator >>
to generate statement iterators for the remote service.

This closure takes C<< ($query, $bridge, \%bound, $subj, $pred, $obj [, $context ] ) >>
as arguments and returns either C<< undef >> if no statements can be generated given
the arguments, or a C<< RDF::Trine::Iterator::Graph >> iterator containing
statements matching C<< $subj, $pred, $obj [, $context ] >>.

=cut

sub computed_statement_generator {
	my $self	= shift;
	my $caps	= $self->capabilities;
	my %preds	= map { $_->{pred}->uri_value => $_ } grep { exists $_->{pred} } @$caps;
	my $l		= Log::Log4perl->get_logger("rdf.query.servicedescription");
	
	return sub {
		my $query	= shift;
		my $bridge	= shift;
		my $bound	= shift;
		my $_cast	= $bridge->can('_cast_to_local');
		my $cast	= sub { my $n = shift; return unless $n; $n->isa('RDF::Query::Node') ? $n : $_cast->( $n ) };
		my $s		= $cast->( shift );
		my $p		= $cast->( shift );
		my $o		= $cast->( shift );
		my $c 		= $cast->( shift );
		return undef if ($c);		# named statements can't be retrieved from another endpoint.
		return undef unless ($p);	# we need a predicate for matching against service capabilities.
		my $puri	= $p->uri_value;
		
		my $cap		= $preds{ $puri };
		if ($self->definitive) {
			return unless ($cap);		# no capability matches this predicate.
		} else {
			$cap	||= {};
		}
		
		my $ok		= 1;
		my $sofilter	= $cap->{ sofilter };
		if ($sofilter) {
			my %vars		= map { $_ => 1 } $sofilter->referenced_variables;
			my $runnable	= 1;
			if ($vars{ subject }) {
				unless ($bound->{subject}) {
					$runnable	= 0;
					$l->debug( "statement generator isn't runnable: subject is not bound" );
				}
			}
			if ($vars{ object }) {
				unless ($bound->{object}) {
					$runnable	= 0;
					$l->debug( "statement generator isn't runnable: object is not bound" );
				}
			}
			if ($runnable) {
				my $bound		= { subject => $s, object => $o };
				my $bool		= RDF::Query::Node::Resource->new( "sparql:ebv" );
				my $filter		= RDF::Query::Expression::Function->new( $bool, $sofilter );
				my $value		= $filter->evaluate( $query, $bound );
				my $nok			= ($value->literal_value eq 'false');
				if ($nok) {
					$ok	= 0;
					$l->debug( "statement generator didn't pass sofilter: " . $sofilter->sse({}, '') );
				}
			}
		}
		
		if ($ok) {
			my @triple	= ($s,$p,$o);
			foreach my $i (0 .. $#triple) {
				my $node	= $triple[$i];
				if ($node->isa('RDF::Query::Node::Blank')) {
					# blank nodes need special handling, since we can't directly reference
					# blank nodes on a remote endpoint.
					
					# for now, we'll just assume that this is a losing battle, and no
					# results are possible when trying to use a blank node to identify
					# remote nodes (which is an acceptable reading of the spec). so return
					# an empty iterator without actually making the remote call.
					return RDF::Trine::Iterator::Bindings->new();
				}
			}
			
			my $st		= RDF::Query::Algebra::Triple->new( @triple );
			$l->debug( "running statement generator for " . $st->sse({}, '') );
			$l->debug( "running statement generator with pre-bound data: " . Dumper($bound) );
			
			my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( $st );
			my $service	= RDF::Query::Algebra::Service->new(
							RDF::Query::Node::Resource->new( $self->url ),
							$ggp
						);
			my $context	= RDF::Query::ExecutionContext->new(
							bound	=> {},
						);
			my ($plan)	= RDF::Query::Plan->generate_plans( $service, $context );
			$plan->execute( $context );
			my $bindings	= RDF::Trine::Iterator::Bindings->new( sub {
				my $vb	= $plan->next;
				return $vb;
			} );
			my $iter	= smap {
							my $bound	= shift;
							my $triple	= $st->bind_variables( $bound );
							$triple->label( origin => $self->url );
							$triple;
						} $bindings;
			return $iter;
		} else {
			return undef;
		}
	};
}


=item C<< answers_triple_pattern ( $triple ) >>

Returns true if the service described by this object can answer queries
comprised of the supplied triple pattern.

=cut

sub answers_triple_pattern {
	my $self	= shift;
	my $triple	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.servicedescription");
	$l->debug( 'checking triple for service compatability: ' . $triple->sse );
	
	my $caps	= $self->capabilities;
	
	my @wildcards	= grep { exists $_->{type} and $_->{type}->uri_value eq 'http://kasei.us/2008/04/sparql#any_triple' } @$caps;
	if (@wildcards) {
		# service can answer any triple pattern, so return true.
		return 1;
	}
	
	my @pred_caps	= grep { exists $_->{pred} } @$caps;
	my $p = $triple->predicate;
	if (not($p->isa('RDF::Trine::Node::Variable'))) {	# if predicate is bound (not a variable)
		my $puri	= $p->uri_value;
		$l->trace("  service compatability based on predicate: $puri");
		my %preds	= map { $_->{pred}->uri_value => $_ } @pred_caps;
		$l->trace("  service supports predicates: " . join(', ', keys %preds));
		my $cap		= $preds{ $puri };
		unless ($cap) {
			# no capability matches this predicate.
			$l->debug("*** service doesn't support the predicate $puri");
			return 0;
		}
		
		my $ok		= 1;
		my $sofilter	= $cap->{ sofilter };
		if ($sofilter) {
			my %vars		= map { $_ => 1 } $sofilter->referenced_variables;
			my $runnable	= 1;
			if ($vars{ subject }) {
				unless ($triple->subject) {
					$l->debug( "triple pattern doesn't match the subject filter" );
					$runnable	= 0;
				}
			}
			if ($vars{ object }) {
				unless ($triple->object) {
					$l->debug( "triple pattern doesn't match the object filter" );
					$runnable	= 0;
				}
			}
			if ($runnable) {
				my $bridge		= RDF::Query->new_bridge;
				my $bound		= { subject => $triple->subject, object => $triple->object };
				my $bool		= RDF::Query::Node::Resource->new( "sparql:ebv" );
				my $filter		= RDF::Query::Expression::Function->new( $bool, $sofilter );
				
				# XXX "ASK {}" is just a simple stand-in query allowing us to have a valid query
				# XXX object to pass to $filter->evaluate below. evaluating a filter really
				# XXX shouldn't require a query object in this case, since it's not going
				# XXX to even touch a datastore, but the code needs to be changed to allow for that.
				my $query		= RDF::Query->new("ASK {}");
				my $value		= $filter->evaluate( $query, $bound );
				my $nok			= ($value->literal_value eq 'false');
				if ($nok) {
					$l->debug( "triple pattern doesn't match the sofilter" );
					$ok	= 0;
				}
			}
		}
		
		return $ok;
	} else {
		# predicate is a variable in the triple pattern. can we matchit based on sparql:pattern?
		$l->trace("service doesn't handle triple patterns with unbound predicates");
		return 0;
	}
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
