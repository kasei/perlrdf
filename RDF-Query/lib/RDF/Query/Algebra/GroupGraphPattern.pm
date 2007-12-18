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
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Iterator qw(sgrep smap swatch);

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
	my $class	= shift;
	my $gp		= @_;
	return bless( [@_], $class );
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

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my %seen;
	foreach my $p ($self->patterns) {
		my @blanks	= $p->referenced_blanks;
		foreach my $b (@blanks) {
			if ($seen{ $b }++) {
				throw RDF::Query::Error::QueryPatternError -text => "Same blank node identifier ($b) used in more than one BasicGraphPattern.";
			}
		}
	}
	return 1;
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
	my $fixed	= $class->new( map { $_->fixup( $bridge, $base, $ns ) } $self->patterns );
	return $fixed;
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
	my @streams;
	my @filters;
	foreach my $triple (@triples) {
		Carp::confess "not an algebra or rdf node: " . Dumper($triple) unless ($triple->isa('RDF::Query::Algebra') or $triple->isa('RDF::Query::Node'));
		my $type	= $triple->type;
		if ($type eq 'FILTER') {
			push(@filters, $triple);
		} else {
			my $stream	= $triple->execute( $query, $bridge, $bound, $context, %args );
			push(@streams, $stream);
		}
	}
	
	if (@streams) {
		while (@streams > 1) {
			my $a	= shift(@streams);
			my $b	= shift(@streams);
			unshift(@streams, RDF::Iterator::Bindings->join_streams( $a, $b, $bridge, %args ));
		}
	} else {
		push(@streams, RDF::Iterator::Bindings->new([{}], []));
	}
	my $stream	= shift(@streams);
	foreach my $data (@filters) {
		$stream	= sgrep {
					my $bound			= $_;
					my $filter_value	= $query->call_function( $bridge, $bound, 'sop:boolean', $data->[1] );
					return ($filter_value);
				} $stream;
	}
	
	return $stream;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
