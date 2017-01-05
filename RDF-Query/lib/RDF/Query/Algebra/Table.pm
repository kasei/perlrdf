# RDF::Query::Algebra::Table
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Table - Algebra class for constant table data

=head1 VERSION

This document describes RDF::Query::Algebra::Table version 2.918.

=cut

package RDF::Query::Algebra::Table;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed refaddr reftype);
use Carp qw(carp croak confess);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap swatch);

######################################################################

our ($VERSION);
my %AS_SPARQL;
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<< new ( \@variables, $row1, $row2, ... ) >>

Returns a new Table structure.

=cut

sub new {
	my $class	= shift;
	my $vars	= shift;
	my @rows	= @_;
	foreach my $t (@rows) {
		unless ($t->isa('RDF::Trine::VariableBindings')) {
			throw RDF::Query::Error::QueryPatternError -text => "Rows belonging to a table must be variable bindings";
		}
	}
	return bless( [ $vars, \@rows ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ([$self->variables], $self->rows);
}

=item C<< variables >>

Returns a list of variable names used in this data table.

=cut

sub variables {
	my $self	= shift;
	return @{ $self->[0] };
}

=item C<< rows >>

Returns a list of variable bindings belonging to this data table.

=cut

sub rows {
	my $self	= shift;
	return @{ $self->[1] };
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $prefix	= shift || '';
	my $indent	= $context->{indent} || '  ';
	my @rows	= sort map { $_->sse( $context ) } $self->rows;
	return sprintf(
		"(table\n${prefix}${indent}%s\n${prefix})",
		join("\n${prefix}${indent}", @rows)
	);
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
	my $string	= "${indent}table\n";
	
	foreach my $t ($self->rows) {
		$string	.= $t->explain($s, $indent+1);
	}
	return $string;
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
		my @values;
		my @vars	= $self->variables;
		foreach my $row ($self->rows) {
			my @row_values;
			foreach my $var (@vars) {
				my $node	= $row->{$var};
				my $value	= ($node) ? $node->as_sparql($context, $indent) : 'UNDEF';
				push(@row_values, $value);
			}
			push(@values, '(' . join(' ', @row_values) . ')');
		}
		my $vars	= join(' ', map { "?$_" } @vars);
		my $string	= "VALUES ($vars) {\n${indent}" . join("\n${indent}", @values) . "\n}\n";
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
		patterns	=> [ map { $_->as_hash } $self->rows ],
	};
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'TABLE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my %vars;
	foreach my $r ($self->rows) {
		$vars{ $_ }++ foreach (keys %$r);
	}
	return keys %vars;
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
