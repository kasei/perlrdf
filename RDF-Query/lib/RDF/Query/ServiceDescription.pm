# RDF::Query::ServiceDescription
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node - Class for describing federated query data sources.

=head1 METHODS

=over 4

=cut

package RDF::Query::ServiceDescription;

BEGIN {
	our $VERSION	= '2.000';
}

use strict;
use warnings;
no warnings 'redefine';

use URI::file;
use RDF::Query;
use RDF::Trine::Iterator qw(smap swatch);
use Scalar::Util qw(blessed);
use Data::Dumper;

=item C<< new ( $url ) >>

Creates a new service description object using the DARQ-style service description
data located at C<< $url >>.

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	
	my $infoquery	= RDF::Query->new( <<"END" );
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
		PREFIX sd: <http://darq.sf.net/dose/0.1#>
		PREFIX foaf: <http://xmlns.com/foaf/0.1/#>
		SELECT ?label ?url ?size ?def
		FROM <$uri>
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
	my ($label, $url, $triples, $def)	= $infoquery->get;
	return undef unless (defined $label);
	my $definitive	= (defined($def) ? ($def->literal_value eq 'true' ? 1 : 0) : 0);
	
	my $capquery	= RDF::Query->new( <<"END" );
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
		PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
		PREFIX sd: <http://darq.sf.net/dose/0.1#>
		PREFIX foaf: <http://xmlns.com/foaf/0.1/#>
		SELECT DISTINCT ?pred ?sofilter ?ssel ?osel ?triples
		FROM <$uri>
		WHERE {
			[] a sd:Service ;
				sd:capability ?cap .
			?cap sd:predicate ?pred .
			OPTIONAL { ?cap sd:sofilter ?sofilter }
			OPTIONAL { ?cap sd:objectSelectivity ?osel }
			OPTIONAL { ?cap sd:subjectSelectivity ?ssel }
			OPTIONAL { ?cap sd:triples ?triples }
		}
END
	my @capabilities;
	my $iter	= $capquery->execute();
	while (my $row = $iter->next) {
		my ($p, $f, $ss, $os, $t)	= @{ $row }{ qw(pred sofilter ssel osel triples) };
		my $data						= { pred => $p };
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
	
	my $data	= {
					label			=> $label->literal_value,
					url				=> $url->uri_value,
					size			=> $triples->literal_value,
					definitive		=> $definitive,
					capabilities	=> \@capabilities,
				};
	my $self	= bless( $data, $class );
	return $self;
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
	my %preds	= map { $_->{pred}->uri_value => $_ } @$caps;
	
	return sub {
		my $query	= shift;
		my $bridge	= shift;
		my $bound	= shift;
		my $s		= shift;
		my $p		= shift;
		my $o		= shift;
		my $c 		= shift;
		return undef if ($c);		# named statements can't be retrieved from another endpoint.
		return undef unless ($p);	# we need a predicate for matching against service capabilities.
		my $puri	= $p->uri_value;
		
		my $cap		= $preds{ $puri };
		return unless ($cap);		# no capability matches this predicate.
		
		my $ok		= 1;
		my $sofilter	= $cap->{ sofilter };
		if ($sofilter) {
			my %vars		= map { $_ => 1 } $sofilter->referenced_variables;
			my $runnable	= 1;
			if ($vars{ subject }) {
				$runnable	= 0 unless ($bound->{subject});
			}
			if ($vars{ object }) {
				$runnable	= 0 unless ($bound->{object});
			}
			if ($runnable) {
				my $bound		= { subject => $s, object => $o };
				my $bool		= RDF::Query::Node::Resource->new( "sparql:ebv" );
				my $filter		= RDF::Query::Expression::Function->new( $bool, $sofilter );
				my $value		= $filter->evaluate( $query, $bridge, $bound );
				my $nok			= ($value->literal_value eq 'false');
				$ok				= 0 if ($nok);
			}
		}
		
		if ($ok) {
			my $st		= RDF::Query::Algebra::Triple->new( $s, $p, $o );
			my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( $st );
			my $service	= RDF::Query::Algebra::Service->new(
							RDF::Query::Node::Resource->new( $self->url ),
							$ggp
						);
			my $iter	= smap {
							my $bound	= shift;
							my $triple	= $st->bind_variables( $bound );
							$triple;
						} $service->execute( $query, $bridge, $bound );
			return $iter;
		} else {
			return undef;
		}
	};
}








1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
