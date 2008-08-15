# RDF::Query::Algebra::Project
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Project - Algebra class for projection

=cut

package RDF::Query::Algebra::Project;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<< new ( $pattern, \@vars_and_exprs ) >>

Returns a new Project structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $vars	= shift;
	return bless( [ $pattern, $vars ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $vars	= $self->vars;
	return ($pattern, $vars);
}

=item C<< pattern >>

Returns the pattern to be sorted.

=cut

sub pattern {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< vars >>

Returns the vars to be projected to.

=cut

sub vars {
	my $self	= shift;
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	my $vars	= join(' ',
					map {
						($_->isa('RDF::Query::Node::Variable')) ? '?' . $_->name : $_->sse( $context )
					} @{ $self->vars }
				);
	return sprintf(
		'(project %s (%s))',
		$self->pattern->sse( $context ),
		$vars
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	return $self->pattern->as_sparql( $context, $indent );
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'PROJECT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my @vars	= $self->pattern->referenced_variables;
	foreach my $v (@{ $self->vars }) {
		if ($v->isa('RDF::Query::Node::Variable')) {
			push(@vars, $v->name);
		} else {
			push(@vars, $v->referenced_variables);
		}
	}
	return uniq(@vars);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $query->algebra_fixup( $self, $bridge, $base, $ns )) {
		return $opt;
	} else {
		return $class->new( $self->pattern->fixup( $query, $bridge, $base, $ns ), $self->vars );
	}
}

# =item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>
# 
# =cut
# 
# sub execute {
# 	my $self		= shift;
# 	my $query		= shift;
# 	my $bridge		= shift;
# 	my $bound		= shift;
# 	my $context		= shift;
# 	my %args		= @_;
# 	
# 	my $stream		= $self->pattern->execute( $query, $bridge, $bound, $context, %args );
# 	
# 	my %seen;
# 	my @variables	= $query->variables;
# 	$stream	= sgrep {
# 		my $row	= $_;
# 		no warnings 'uninitialized';
# 		my $key	= join($;, map {$bridge->as_string( $_ )} map { $row->{$_} } @variables);
# 		return (not $seen{ $key }++);
# 	} $stream;
# 	
# 	return $stream;
# }


=item C<< is_solution_modifier >>

Returns true if this node is a solution modifier.

=cut

sub is_solution_modifier {
	return 1;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
