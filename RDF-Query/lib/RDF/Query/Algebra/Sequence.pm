# RDF::Query::Algebra::Sequence
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Sequence - Algebra class for a sequence of algebra operations

=head1 VERSION

This document describes RDF::Query::Algebra::Sequence version 2.910.

=cut

package RDF::Query::Algebra::Sequence;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr reftype blessed);
use Carp qw(carp croak confess);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap swatch);

######################################################################

our ($VERSION);
my %AS_SPARQL;
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( @patterns )>

Returns a new Sequence structure.

=cut

sub new {
	my $class	= shift;
	my @patterns	= @_;
	return bless( [ @patterns ] );
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

Returns a list of patterns belonging to this sequence.

=cut

sub patterns {
	my $self	= shift;
	return @$self;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my @patterns	= map { $_->sse( $context ) } $self->patterns;
	return sprintf(
		"(sequence\n${prefix}${indent}%s\n${prefix})",
		join("\n${prefix}${indent}", @patterns)
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	if (exists $AS_SPARQL{ refaddr( $self ) }) {
		return $AS_SPARQL{ refaddr( $self ) };
	} else {
		my $context	= shift;
# 		if (ref($context)) {
# 			$context	= { %$context };
# 		}
		my $indent	= shift || '';
		my @patterns;
		foreach my $t ($self->patterns) {
			push(@patterns, $t->as_sparql( $context, $indent ));
		}
		my $string	= join(" ;\n${indent}", @patterns);
		$AS_SPARQL{ refaddr( $self ) }	= $string;
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

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SEQUENCE';
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
	my @patterns	= $self->patterns;
	return $patterns[ $#patterns ]->potentially_bound;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my @patterns	= $self->patterns;
	return $patterns[ $#patterns ]->potentially_bound;
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->patterns );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->patterns );
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg (grep { blessed($_) and $_->isa('RDF::Query::Algebra::Update') and $_->data_only } $self->construct_args) {
		push(@data, [$arg, $arg->_referenced_blanks()]);
	}
	
	my %seen;
	foreach my $d (@data) {
		my ($pat, $data)	= @$d;
		foreach my $b (@$data) {
			if ($seen{ $b }) {
				throw RDF::Query::Error::QueryPatternError -text => "Same blank node identifier ($b) used in more than one BasicGraphPattern.";
			}
			$seen{ $b }	= $pat;
		}
	}
	
	return 1;
}

sub _referenced_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->pattern) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push( @data, $arg->_referenced_blanks );
		}
	}
	return @data;
}

sub DESTROY {
	my $self	= shift;
	delete $AS_SPARQL{ refaddr( $self ) };
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
