# RDF::Query::Algebra::Filter
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Filter - Algebra class for Filter expressions

=cut

package RDF::Query::Algebra::Filter;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(sgrep smap swatch);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

# function
# operator
# 	unary
# 	binary


our %OPERATORS	= (
	'~~'	=> {
				arity	=> { 2 => 'REGEX(%s, %s)', 3 => "REGEX(%s, %s, %s)" },
			},
	'=='	=> {
				arity	=> { 2 => '%s = %s' },
			},
	'!='	=> {
				arity	=> { 2 => '%s != %s' },
			},
	'<'		=> {
				arity	=> { 2 => '%s < %s' },
			},
	'>'		=> {
				arity	=> { 2 => '%s > %s' },
			},
	'<='	=> {
				arity	=> { 2 => '%s <= %s' },
			},
	'>='	=> {
				arity	=> { 2 => '%s >= %s' },
			},
	'&&'	=> {
				arity	=> { 2 => '%s && %s' },
			},
	'||'	=> {
				arity	=> { 2 => '%s || %s' },
			},
	'*'		=> {
				arity	=> { 2 => '%s * %s' },
			},
	'/'		=> {
				arity	=> { 2 => '%s / %s' },
			},
	'+'		=> {
				arity	=> { 2 => '%s + %s' },
			},
	'-'		=> {
				arity	=> { 1 => '-%s', 2 => '%s - %s' },
			},
	'!'		=> {
				arity	=> { 1 => '! %s' },
			},
);


=head1 METHODS

=over 4

=cut

=item C<new ( $expression, $pattern )>

Returns a new Filter structure.

=cut

sub new {
	my $class	= shift;
	my $expr	= shift;
	my $pattern	= shift;
	Carp::confess unless ($pattern->isa('RDF::Query::Algebra::GroupGraphPattern') or $pattern->isa('RDF::Query::Algebra::BasicGraphPattern') or $pattern->isa('RDF::Query::Algebra::Filter'));
	return bless( [ 'FILTER', $expr, $pattern ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->expr, $self->pattern);
}

=item C<< expr >>

Returns the filter expression.

=cut

sub expr {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< pattern >>

Returns the filter pattern.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		my $pattern	= shift;
		Carp::confess unless ($pattern->isa('RDF::Query::Algebra::GroupGraphPattern'));
		$self->[2]	= $pattern;
	}
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(filter %s %s)',
		$self->expr->sse( $context ),
		$self->pattern->sse( $context ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	die;
	
	my $expr	= $self->expr;
	my ($op, @ops)	= @{ $expr };
	if (exists($OPERATORS{$op})) {
		my $data	= $OPERATORS{ $op };
		my $arity	= scalar(@ops);
		if (exists($data->{arity}{$arity})) {
			my $template	= $data->{arity}{$arity};
			my $expr	= sprintf( $template, map { $_->as_sparql( $context, $indent ) } @ops );
			my $string	= sprintf(
				"FILTER %s",
				$expr,
			);
			return $string;
		} else {
			warn "Operator '$op' is not defined for arity of $arity\n";
			die;
		}
	} else {
		die Dumper($expr);
	}
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'FILTER';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my $expr	= $self->expr;
	my $pattern	= $self->pattern;
	my @vars	= $pattern->referenced_variables;
	if (blessed($expr) and $expr->isa('RDF::Query::Algebra')) {
		return uniq(@vars, $self->expr->referenced_variables);
	} elsif (blessed($expr) and $expr->isa('RDF::Query::Node::Variable')) {
		return uniq(@vars, $expr->name);
	} else {
		return (@vars);
	}
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	my $pattern	= $self->pattern;
	return $pattern->definite_variables;
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
	
	my $expr	= $self->expr->fixup( $bridge, $base, $ns );
	my $pattern	= $self->pattern->fixup( $bridge, $base, $ns );
	return $class->new( $expr, $pattern );
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
	
	my $expr		= $self->expr;
	my $pattern		= $self->pattern;
	my $stream		= sgrep {
						my $bound			= $_;
						my $filter_value	= $query->call_function( $bridge, $bound, 'sop:boolean', $expr );
						return ($filter_value);
					} $pattern->execute( $query, $bridge, $bound, $context, %args );
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
