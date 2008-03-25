# RDF::Query::Algebra::BasicGraphPattern
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::BasicGraphPattern - Algebra class for BasicGraphPattern patterns

=cut

package RDF::Query::Algebra::BasicGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( @triples )>

Returns a new BasicGraphPattern structure.

=cut

sub new {
	my $class	= shift;
	my @triples	= @_;
	foreach my $t (@triples) {
		unless ($t->isa('RDF::Trine::Statement')) {
			Carp::cluck;
			throw RDF::Query::Error::QueryPatternError -text => "Patterns belonging to a BGP must be graph statements";
		}
	}
	return bless( [ @triples ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->triples);
}

=item C<< triples >>

Returns a list of triples belonging to this BGP.

=cut

sub triples {
	my $self	= shift;
	return @$self;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(bgp %s)',
		join(' ', map { $_->sse( $context ) } $self->triples)
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my @triples;
	foreach my $t ($self->triples) {
		push(@triples, $t->as_sparql( $context, $indent ));
	}
	my $string	= join("\n${indent}", @triples);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'BGP';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq(map { $_->referenced_variables } $self->triples);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return uniq(map { $_->definite_variables } $self->triples);
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub _check_duplicate_blanks {
	my $self	= shift;
	my %seen;
	foreach my $t ($self->triples) {
		my @blanks	= $t->referenced_blanks;
		foreach my $b (@blanks) {
			$seen{ $b }++;
		}
	}
	return [keys %seen];
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
	
	my @nodes	= map { $_->fixup( $bridge, $base, $ns ) } $self->triples;
	my $fixed	= $class->new( @nodes );
	return $fixed;
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->triples );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->triples );
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
	
	if ($bridge->can('unify_bgp')) {
		return $bridge->unify_bgp( $self, $bound, $context, %args );
	} else {
		my (@triples)	= $self->triples;
		my @streams;
		foreach my $triple (@triples) {
			Carp::confess "not an algebra or rdf node: " . Dumper($triple) unless ($triple->isa('RDF::Trine::Statement'));
			my $stream	= $triple->execute( $query, $bridge, $bound, $context, %args );
			push(@streams, $stream);
		}
		if (@streams) {
			while (@streams > 1) {
				my $a	= shift(@streams);
				my $b	= shift(@streams);
				unshift(@streams, RDF::Trine::Iterator::Bindings->join_streams( $a, $b ));
			}
		} else {
			push(@streams, RDF::Trine::Iterator::Bindings->new([{}], []));
		}
		my $stream	= shift(@streams);
		return $stream;
	}
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
