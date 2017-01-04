# RDF::Query::Algebra::Aggregate
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Aggregate - Algebra class for aggregate patterns

=head1 VERSION

This document describes RDF::Query::Algebra::Aggregate version 2.918.

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
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $pattern, \@groupby, $alias => [$op => $col] )>

=item C<new ( $pattern, \@groupby, expressions => [ $alias => [$op, \%options, @cols] ] )>

Returns a new Aggregate structure. Groups by the named bindings in C<< @groupby >>,
and returns new bindings for the named C<< $alias >> for the operation C<< $op >>
on column C<< $col >>.

C<< $op >> may be one of: COUNT, MIN, MAX, SUM.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $groupby	= shift;
	my @ops;
	if (scalar(@_) and ref($_[0]) and reftype($_[0]) eq 'HASH') {
		my $hash	= shift;
		@ops		= @{ $hash->{ 'expressions' } || [] };
	} else {
		while (@_) {
			my ($alias, $data)	= splice(@_,0,2,());
			my $op	= shift(@$data);
			my @data	= ($op, {}, @$data);
			push(@ops, $alias, \@data);
		}
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

Returns a list of tuples as ARRAY refs containing C<< $alias, $op, @cols >>.

=cut

sub ops {
	my $self	= shift;
	my @ops		= @{ $self->[2] };
	my @tuples;
	while (@ops) {
		my $alias	= shift(@ops);
		my $data	= shift(@ops);
		my ($op, $opts, @col)	= @$data;
		push(@tuples, [$alias, $op, $opts, @col]);
	}
	return @tuples;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= ($context->{indent} ||= '  ');
	
	my @ops_sse;
	my @ops		= $self->ops;
	foreach my $data (@ops) {
		my ($alias, $op, $opts, @cols)	= @$data;
		my @col_strings	= map { (not(blessed($_)) and $_ eq '*') ? '*' : $_->sse( $context, "${prefix}${indent}" ) } @cols;
		my $col_string	= join(' ', @col_strings);
		if (@col_strings > 1) {
			$col_string	= '(' . $col_string . ')';
		}
		my %op_opts	= %{ $opts || {} };
		my @opts_keys	= keys %op_opts;
		if (@opts_keys) {
			my $opt_string	= '(' . join(' ', map { $_, qq["$op_opts{$_}"] } @opts_keys) . ')';
			push(@ops_sse, sprintf('(alias "%s" (%s %s %s))', $alias, $op, $col_string, $opt_string));
		} else {
			push(@ops_sse, sprintf('(alias "%s" (%s %s))', $alias, $op, $col_string));
		}
	}
	
	my @group	= $self->groupby;
	my $group	= (@group) ? '(' . join(', ', map {$_->sse($context, $prefix)} @group) . ')' : '';
	return sprintf(
		"(aggregate\n${prefix}${indent}%s\n${prefix}${indent}(%s)\n${prefix}${indent}%s)",
		$self->pattern->sse( $context, "${prefix}${indent}" ),
		join(', ', @ops_sse),
		$group,
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	return $self->pattern->as_sparql($context, $indent);
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	
	my @ops	= $self->ops;
	my @expressions;
	foreach my $o (@ops) {
		my ($alias, $op, $agg_options, @cols)	= @$o;
		push(@expressions, { alias => $alias, op => $op, scalarvals => $agg_options, columns => [ map { $_->as_hash } @cols ] });
	}
	
	return {
		type 		=> lc($self->type),
		pattern		=> $self->pattern->as_hash,
		groupby		=> [ map { $_->as_hash } $self->groupby ],
		expressions	=> \@expressions,
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

=item C<< potentially_bound >>

Returns a list of the variable names used in this algebra expression that will
bind values during execution.

=cut

sub potentially_bound {
	my $self	= shift;
	my @vars;
#	push(@vars, map { $_->[0] } $self->ops);
	foreach my $g ($self->groupby) {
		if (blessed($g)) {
			if ($g->isa('RDF::Query::Node::Variable')) {
				push(@vars, $g->name);
			} elsif ($g->isa('RDF::Query::Expression::Alias')) {
				push(@vars, $g->name);
			}
		}
	}
	return RDF::Query::_uniq(@vars);
#	return RDF::Query::_uniq( @aliases, $self->pattern->referenced_variables );
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
