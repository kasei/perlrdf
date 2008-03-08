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

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
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
		
		### cooperate with ::Algebra::Service so that if we've already got a stream
		### of results from previous patterns, and the next pattern is a remote
		### service call, we can try to send along a bloom filter function.
		### if it doesn't work (the remote endpoint may not support the kasei:bloom
		### function), then fall back on making the call without the filter.
		try {
			if ($stream and $triple->isa('RDF::Query::Algebra::Service')) {
# 				local($RDF::Trine::Iterator::debug)	= 1;
				my $m		= $stream->materialize;
				
				my @vars	= $triple->referenced_variables;
				my %svars	= map { $_ => 1 } $stream->binding_names;
				my $var		= RDF::Query::Node::Variable->new( first { $svars{ $_ } } @vars );
				
				my $f		= RDF::Query::Algebra::Service->bloom_filter_for_iterator( $query, $bridge, $bound, $m, $var, 0.001 );
				
				my $new;
				try {
					my $pattern	= $triple->add_bloom( $var, $f );
					$new	= $pattern->execute( $query, $bridge, $bound, $context, %args );
					throw RDF::Query::Error unless ($new);
				} otherwise {
					warn "*** Wasn't able to use k:bloom as a FILTER restriction in SERVICE call.\n" if ($debug);
					$new	= $triple->execute( $query, $bridge, $bound, $context, %args );
				};
				$stream	= RDF::Trine::Iterator::Bindings->join_streams( $m, $new, %args, query => $query, bridge => $bridge );
				$handled	= 1;
			}
		};
		
		unless ($handled) {
			my $new	= $triple->execute( $query, $bridge, $bound, $context, %args );
			if ($stream) {
				$stream	= RDF::Trine::Iterator::Bindings->join_streams( $stream, $new, %args, query => $query, bridge => $bridge )
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

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
