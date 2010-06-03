# RDF::Query::Algebra::Aggregate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Aggregate - Algebra class for aggregate patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Aggregate version 2.202, released 30 January 2010.

=cut

package RDF::Query::Algebra::Aggregate;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Scalar::Util qw(blessed reftype);
use Data::Dumper;
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.202';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, \@groupby, $alias => [$op => $col] )>

=item C<new ( $pattern, \@groupby, expressions => [ $alias => [$op => $col] ] )>

Returns a new Aggregate structure. Groups by the named bindings in C<< @groupby >>,
and returns new bindings for the named C<< $alias >> for the operation C<< $op >>
on column C<< $col >>.

C<< $op >> may be one of: COUNT, MIN, MAX, SUM.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $groupby	= shift;
	my (@ops);
	if (scalar(@_) and ref($_[0]) and reftype($_[0]) eq 'HASH') {
		my $hash	= shift;
		@ops		= @{ $hash->{ 'expressions' } || [] };
	} else {
		@ops		= @_;
	}
	
	return bless( [ $pattern, $groupby, \@ops ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my @ops		= @{ $self->[2] };
	return ($self->pattern, [ $self->groupby ], { expressions => \@ops });
}

=item C<< pattern >>

Returns the aggregates pattern.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0];
}

=item C<< groupby >>

Returns the aggregate's GROUP BY binding names.

=cut

sub groupby {
	my $self	= shift;
	return @{ $self->[1] };
}

=item C<< ops >>

Returns a list of tuples as ARRAY refs containing C<< $alias, $op, $col >>.

=cut

sub ops {
	my $self	= shift;
	my @ops		= @{ $self->[2] };
	my @tuples;
	while (@ops) {
		my $alias	= shift(@ops);
		my $data	= shift(@ops);
		my ($op, $col)	= @$data;
		push(@tuples, [$alias, $op, $col]);
	}
	return @tuples;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	
	my @ops_sse;
	my @ops		= $self->ops;
	foreach my $data (@ops) {
		my ($alias, $op, $col)	= @$data;
		push(@ops_sse, sprintf('(alias "%s" (%s %s))', $alias, $op, ($col eq '*' ? '*' : $col->sse( $context, "${prefix}${indent}" ))));
	}
	
	my @group	= $self->groupby;
	my $group	= (@group) ? '(' . join(', ', @group) . ')' : '';
	return sprintf(
		"(aggregate\n${prefix}${indent}%s\n${prefix}${indent}%s\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		join(', ', @ops_sse),
		$group,
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	throw RDF::Query::Error::SerializationError -text => "Aggregates can't be serialized as SPARQL";
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		groupby		=> [ map { $_->as_hash } $self->groupby ],
		expressions	=> [ map { $_->as_hash } $self->ops ],
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'AGGREGATE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	return RDF::Query::_uniq( @aliases, $self->pattern->referenced_variables );
}

=item C<< binding_variables >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub binding_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	throw Error; # XXX unimplemented
	return RDF::Query::_uniq( @aliases, $self->pattern->referenced_variables );
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my @aliases	= map { $_->[0] } $self->ops;
	return @aliases;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
