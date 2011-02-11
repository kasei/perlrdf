=head1 NAME

RDF::Query::Functions::Kasei - RDF-Query-specific functions

=head1 VERSION

This document describes RDF::Query::Functions::Kasei version 2.904_01.

=head1 DESCRIPTION

Defines the following functions:

=over

=item * http://kasei.us/2007/09/functions/warn

=item * http://kasei.us/code/rdf-query/functions/bloom

=item * http://kasei.us/code/rdf-query/functions/bloom/filter

=back

=cut

package RDF::Query::Functions::Kasei;

use strict;
use warnings;
use Log::Log4perl;
our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.kasei");
	$VERSION	= '2.904_01';
}

use Data::Dumper;
use Scalar::Util qw(blessed reftype refaddr looks_like_number);

my $BLOOM_URL	= 'http://kasei.us/code/rdf-query/functions/bloom';

### func:bloom( ?var, "frozen-bloom-filter" ) => true iff str(?var) is in the bloom filter.
our $BLOOM_FILTER_LOADED;
BEGIN {
	$RDF::Query::Functions::BLOOM_FILTER_LOADED = # back-compat
	$BLOOM_FILTER_LOADED	= do {
		eval {
			require Bloom::Filter;
		};
		($@)
			? 0
			: (Bloom::Filter->can('thaw'))
				? 1
				: 0;
	};
}

=begin private

=item C<< install >>

Documented in L<RDF::Query::Functions>.

=end private

=cut

sub install
{	
	RDF::Query::Functions->install_function(
		"http://kasei.us/2007/09/functions/warn",
		sub {
			my $query	= shift;
			my $value	= shift;
			my $func	= RDF::Query::Expression::Function->new( 'sparql:str', $value );
			
			my $string	= Dumper( $func->evaluate( undef, undef, {} ) );
			no warnings 'uninitialized';
			warn "FILTER VALUE: $string\n";
			return $value;
		}
	);

	{
		sub _BLOOM_ADD_NODE_MAP_TO_STREAM {
			my $query	= shift;
				my $stream	= shift;
			$l->debug("bloom filter got result stream\n");
			my $nodemap	= $query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' };
			$stream->add_extra_result_data('bnode-map', $nodemap);
		}
		push( @{ $RDF::Query::hooks{ 'http://kasei.us/code/rdf-query/hooks/function_init' } }, sub {
			my $query		= shift;
			my $function	= shift;
			if ($function->uri_value eq $BLOOM_URL) {
				$query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' }	||= {};
				$query->add_hook_once( 'http://kasei.us/code/rdf-query/hooks/post-execute', \&_BLOOM_ADD_NODE_MAP_TO_STREAM, "${BLOOM_URL}#add_node_map" );
			}
		} );
		RDF::Query::Functions->install_function(
			$BLOOM_URL,
			sub {
				my $query	= shift;
					
				my $value	= shift;
				my $filter	= shift;
				my $bloom;
				
				unless ($BLOOM_FILTER_LOADED) {
					$l->warn("Cannot compute bloom filter because Bloom::Filter is not available");
					throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute bloom filter because Bloom::Filter is not available" );
				}
				
				$l->debug("k:bloom being executed with node " . $value);
				
				if (exists( $query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter } )) {
					$bloom	= $query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter };
				} else {
					my $value	= $filter->literal_value;
					$bloom	= Bloom::Filter->thaw( $value );
					$query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter }	= $bloom;
				}
				
				my $seen	= $query->{_query_cache}{ $BLOOM_URL }{ 'node_name_cache' }	= {};
				die 'kasei:bloom died: no bridge anymore'; # no bridge anymore!
				my $bridge;
				my @names	= RDF::Query::Algebra::Service->_names_for_node( $value, $query, $bridge, {}, {}, 0, '', $seen );
				$l->debug("- " . scalar(@names) . " identity names for node");
				foreach my $string (@names) {
					$l->debug("checking bloom filter for --> '$string'\n");
					my $ok	= $bloom->check( $string );
					$l->debug("-> ok") if ($ok);
					if ($ok) {
						my $nodemap	= $query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' };
						push( @{ $nodemap->{ $value->as_string } }, $string );
						return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					}
				}
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		);
	}
	
	RDF::Query::Functions->install_function(
		"http://kasei.us/code/rdf-query/functions/bloom/filter",
		sub {
			my $query	= shift;
			
			my $value	= shift;
			my $filter	= shift;
			my $bloom;
			
			unless ($BLOOM_FILTER_LOADED) {
				throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute bloom filter because Bloom::Filter is not available" );
			}
			
			if (ref($query) and exists( $query->{_query_cache}{ "http://kasei.us/code/rdf-query/functions/bloom/filter" }{ 'filters' }{ $filter } )) {
				$bloom	= $query->{_query_cache}{ "http://kasei.us/code/rdf-query/functions/bloom/filter" }{ 'filters' }{ $filter };
			} else {
				my $value	= $filter->literal_value;
				$bloom	= Bloom::Filter->thaw( $value );
				if (ref($query)) {
					$query->{_query_cache}{ "http://kasei.us/code/rdf-query/functions/bloom/filter" }{ 'filters' }{ $filter }	= $bloom;
				}
			}
			
			my $string	= $value->as_string;
			$l->debug("checking bloom filter for --> '$string'\n");
			my $ok	= $bloom->check( $string );
			$l->debug("-> ok") if ($ok);
			if ($ok) {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
}


1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
