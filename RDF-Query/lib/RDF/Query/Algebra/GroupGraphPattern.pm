# RDF::Query::Algebra::GroupGraphPattern
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::GroupGraphPattern - Algebra class for GroupGraphPattern patterns

=cut

package RDF::Query::Algebra::GroupGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Scalar::Util qw(blessed);
use Data::Dumper;
use List::Util qw(first);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Query::Error qw(:try);
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	our %SERVICE_BLOOM_IGNORE	= ('http://dbpedia.org/sparql' => 1);	# by default, assume dbpedia doesn't implement k:bloom().
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( @graph_patterns )>

Returns a new GroupGraphPattern structure.

=cut

sub new {
	my $class		= shift;
	my @patterns	= @_;
	my $self	= bless( \@patterns, $class );
	if (@patterns) {
		Carp::confess unless blessed($patterns[0]);
	}
	return $self;
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->patterns);
}

=item C<< patterns >>

Returns a list of the graph patterns in this GGP.

=cut

sub patterns {
	my $self	= shift;
	return @{ $self };
}

=item C<< add_pattern >>

Appends a new child pattern to the GGP.

=cut

sub add_pattern {
	my $self	= shift;
	my $pattern	= shift;
	push( @{ $self }, $pattern );
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(join %s)',
		join(' ', map { $_->sse( $context ) } $self->patterns)
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my @patterns;
	foreach my $p ($self->patterns) {
		push(@patterns, $p->as_sparql( $context, "$indent\t" ));
	}
	my $patterns	= join("\n${indent}\t", @patterns);
	my $string	= sprintf("{\n${indent}\t%s\n${indent}}", $patterns);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'GGP';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq(map { $_->referenced_variables } $self->patterns);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return uniq(map { $_->definite_variables } $self->patterns);
}

=item C<< fixup ( $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;

	my @triples	= $self->patterns;
	
	my $ggp			= $class->new( map { $_->fixup( $bridge, $base, $ns ) } @triples );
	return $ggp;
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	
	my (@triples)	= $self->patterns;
	my $stream;
	foreach my $triple (@triples) {
		Carp::confess "not an algebra or rdf node: " . Dumper($triple) unless ($triple->isa('RDF::Query::Algebra') or $triple->isa('RDF::Query::Node'));
		
		my $handled	= 0;
		
		our %SERVICE_BLOOM_IGNORE;	# keep track of which service calls throw an error so we don't keep trying it...
		
		### cooperate with ::Algebra::Service so that if we've already got a stream
		### of results from previous patterns, and the next pattern is a remote
		### service call, we can try to send along a bloom filter function.
		### if it doesn't work (the remote endpoint may not support the kasei:bloom
		### function), then fall back on making the call without the filter.
		try {
			if ($stream and $triple->isa('RDF::Query::Algebra::Service')) {
				unless ($SERVICE_BLOOM_IGNORE{ $triple->endpoint->uri_value }) {
	# 				local($RDF::Trine::Iterator::debug)	= 1;
					$stream		= $stream->materialize;
					my $m		= $stream;
					
					my @vars	= $triple->referenced_variables;
					my %svars	= map { $_ => 1 } $stream->binding_names;
					my $var		= RDF::Query::Node::Variable->new( first { $svars{ $_ } } @vars );
					
					my $error	= $query->{_bloom_filter_error} || $RDF::Query::Algebra::Service::BLOOM_FILTER_ERROR_RATE || 0.001;
					my $f		= RDF::Query::Algebra::Service->bloom_filter_for_iterator( $query, $bridge, $bound, $m, $var, $error );
					
					my $pattern	= $triple->add_bloom( $var, $f );
					my $new	= $pattern->execute( $query, $bridge, $bound, $context, %args );
					throw RDF::Query::Error unless ($new);
					$stream	= $self->join_bnode_streams( $m, $new, $query, $bridge, $bound );
					$handled	= 1;
				}
			}
		} otherwise {
			$SERVICE_BLOOM_IGNORE{ $triple->endpoint->uri_value }	= 1;
			warn "*** Wasn't able to use k:bloom as a FILTER restriction in SERVICE call.\n" if ($debug);
		};
		
		unless ($handled) {
			my $new	= $triple->execute( $query, $bridge, $bound, $context, %args );
			if ($stream) {
				$stream	= RDF::Trine::Iterator::Bindings->join_streams( $stream, $new, %args )
			} else {
				$stream	= $new;
			}
		}
	}
	
	unless ($stream) {
		$stream	= RDF::Trine::Iterator::Bindings->new([{}], []);
	}
	
	return $stream;
}

=item C<< join_bnode_streams ( $streamA, $streamB, $query, $bridge ) >>

A modified inner-loop join that relies on there being bnode identity hints in
the data returned by C<< $streamB->extra_result_data >>. These hints are
combined with locally computed identity values for the items from C<< $streamA >>
and the streams are merged using a natural join where equality is computed
either on direct node equality or on any intersection of the identity hints.

The identity hints and locally computed identity values are computed using
Functional and InverseFunctional property values using N3 syntax. For example,
a blank node '(r1)' might have identity hints using foaf:mbox_sha1sum such as:

  $extra_result_data = {
      'bnode-map' => [ {
          '(r1)' => ['!<http://xmlns.com/foaf/0.1/mbox_sha1sum>"26fb6400147dcccfda59717ff861db9cb97ac5ec"']
      } ]
  };

=cut

sub join_bnode_streams {
	my $self	= shift;
	my $astream	= shift;
	my $bstream	= shift;
	my $query	= shift;
	my $bridge	= shift;
	
	Carp::confess unless ($astream->isa('RDF::Trine::Iterator::Bindings'));
	Carp::confess unless ($bstream->isa('RDF::Trine::Iterator::Bindings'));
	
	################################################
	### BNODE MAP STUFF
	my $b_extra	= $bstream->extra_result_data || {};
	my (%b_map);
	foreach my $h (@{ $b_extra->{'bnode-map'} || [] }) {
		foreach my $id (keys %$h) {
			my @values	= @{ $h->{ $id } };
			push( @{ $b_map{ $id } }, @values );
		}
	}
	my $b_map	= (%b_map) ? \%b_map : undef;
	################################################
	
	my @names	= uniq( map { $_->binding_names() } ($astream, $bstream) );
	my $a		= $astream->project( @names );
	my $b		= $bstream->project( @names );
	
	my @results;
	my @data	= $b->get_all();
	no warnings 'uninitialized';
	while (my $rowa = $a->next) {
		LOOP: foreach my $rowb (@data) {
			warn "[--JOIN--] " . join(' ', map { my $row = $_; '{' . join(', ', map { join('=', $_, ($row->{$_}) ? $row->{$_}->as_string : '(undef)') } (keys %$row)) . '}' } ($rowa, $rowb)) . "\n" if ($debug);
			my %keysa	= map {$_=>1} (keys %$rowa);
			my @shared	= grep { $keysa{ $_ } } (keys %$rowb);
			foreach my $key (@shared) {
				my $val_a	= $rowa->{ $key };
				my $val_b	= $rowb->{ $key };
				my $defined	= 0;
				foreach my $n ($val_a, $val_b) {
					$defined++ if (defined($n));
				}
				if ($defined == 2) {
					my $equal	= $val_a->equal( $val_b );
					if (not $equal) {
						my $names	= $b_map->{ $val_b->as_string };
						if ($names) {
							my $bnames	= Set::Scalar->new( @{ $names } );
							my $anames	= Set::Scalar->new( RDF::Query::Algebra::Service->_names_for_node( $val_a, $query, $bridge, {} ) );
							if ($debug) {
								warn "anames: $anames\n";
								warn "bnames: $bnames\n";
							}
							if (my $int = $anames->intersection( $bnames )) {
								warn "node equality based on $int" if ($debug);
								$equal	= 1;
							}
						}
					}
					
					unless ($equal) {
						warn "can't join because mismatch of $key (" . join(' <==> ', map {$_->as_string} ($val_a, $val_b)) . ")" if ($debug);
						next LOOP;
					}
				}
			}
			
			my $row	= { (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa), (map { $_ => $rowb->{$_} } grep { defined($rowb->{$_}) } keys %$rowb) };
			if ($debug) {
				warn "JOINED:\n";
				foreach my $key (keys %$row) {
					warn "$key\t=> " . $row->{ $key }->as_string . "\n";
				}
			}
			push(@results, $row);
		}
	}
	
	my $args	= $astream->_args;
	return $astream->_new( \@results, 'bindings', \@names, %$args );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
