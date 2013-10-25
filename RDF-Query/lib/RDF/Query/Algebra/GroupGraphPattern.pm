# RDF::Query::Algebra::GroupGraphPattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::GroupGraphPattern - Algebra class for GroupGraphPattern patterns

=head1 VERSION

This document describes RDF::Query::Algebra::GroupGraphPattern version 2.910.

=cut

package RDF::Query::Algebra::GroupGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Log::Log4perl;
use Scalar::Util qw(blessed refaddr);
use Data::Dumper;
use List::Util qw(first);
use Carp qw(carp croak confess);
use RDF::Query::Error qw(:try);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.910';
	our %SERVICE_BLOOM_IGNORE	= ('http://dbpedia.org/sparql' => 1);	# by default, assume dbpedia doesn't implement k:bloom().
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( @graph_patterns )>

Returns a new GroupGraphPattern structure.

=cut

sub new {
	my $class		= shift;
	my @patterns	= @_;
	my $self	= bless( \@patterns, $class );
	foreach my $p (@patterns) {
		unless (blessed($p)) {
			Carp::cluck;
			throw RDF::Query::Error::MethodInvocationError -text => "GroupGraphPattern constructor called with unblessed value";
		}
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

=item C<< quads >>

Returns a list of the quads belonging to this GGP.

=cut

sub quads {
	my $self	= shift;
	my @quads;
	my %bgps;
	foreach my $p ($self->subpatterns_of_type('RDF::Query::Algebra::NamedGraph')) {
		push(@quads, $p->quads);
		foreach my $bgp ($p->subpatterns_of_type('RDF::Query::Algebra::BasicGraphPattern')) {
			$bgps{ refaddr($bgp) }++;
		}
	}
	foreach my $p ($self->subpatterns_of_type('RDF::Query::Algebra::BasicGraphPattern')) {
		next if ($bgps{ refaddr($p) });
		push(@quads, $p->quads);
	}
	return @quads;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= ($context->{indent} ||= "\t");
	
	my @patterns	= $self->patterns;
	if (scalar(@patterns) == 1) {
		return $patterns[0]->sse( $context, $prefix );
	} else {
		return sprintf(
			"(join\n${prefix}${indent}%s)",
			join("\n${prefix}${indent}", map { $_->sse( $context, "${prefix}${indent}" ) } @patterns)
		);
	}
}

=item C<< explain >>

Returns a string serialization of the algebra appropriate for display on the
command line.

=cut

sub explain {
	my $self	= shift;
	my $s		= shift;
	my $count	= shift;
	my $indent	= $s x $count;
	my $string	= "${indent}group graph pattern\n";

	my @patterns	= $self->patterns;
	if (scalar(@patterns) == 1) {
		$string	.= $patterns[0]->explain( $s, $count+1 );
	} else {
		foreach my $p (@patterns) {
			$string	.= $p->explain( $s, $count+1 );
		}
	}
	return $string;
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift || '';
	my $force	= $context->{force_ggp_braces};
	$force		= 0 unless (defined($force));
	if ($force) {
		$context->{force_ggp_braces}--;
	}
	
	my @patterns;
	my @p	= $self->patterns;
	
	if (scalar(@p) == 0) {
		return "{}";
	} elsif (scalar(@p) == 1 and not($force)) {
		return $p[0]->as_sparql($context, $indent);
	} else {
		foreach my $p (@p) {
			push(@patterns, $p->as_sparql( $context, "$indent\t" ));
		}
		my $patterns	= join("\n${indent}\t", @patterns);
		my $string		= sprintf("{\n${indent}\t%s\n${indent}}", $patterns);
		return $string;
	}
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		patterns	=> [ map { $_->as_hash } $self->patterns ],
	};
}

=item C<< as_spin ( $model ) >>

Adds statements to the given model to represent this algebra object in the
SPARQL Inferencing Notation (L<http://www.spinrdf.org/>).

=cut

sub as_spin {
	my $self	= shift;
	my $model	= shift;
	return map { $_->as_spin($model) } $self->patterns;
	
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
	return RDF::Query::_uniq(map { $_->referenced_variables } $self->patterns);
}

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	return RDF::Query::_uniq(map { $_->potentially_bound } $self->patterns);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Query::_uniq(map { $_->definite_variables } $self->patterns);
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@data, $arg->_referenced_blanks());
		}
	}
	
	my %seen;
	foreach my $d (@data) {
		foreach my $b (@$d) {
			if ($seen{ $b }++) {
				throw RDF::Query::Error::QueryPatternError -text => "Same blank node identifier ($b) used in more than one BasicGraphPattern.";
			}
		}
	}
	
	return 1;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
