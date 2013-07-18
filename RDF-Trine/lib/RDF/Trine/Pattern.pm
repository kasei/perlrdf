# RDF::Trine::Pattern
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Pattern - Class for basic graph patterns

=head1 VERSION

This document describes RDF::Trine::Pattern version 1.007

=cut

package RDF::Trine::Pattern;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed refaddr);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.007';
}

######################################################################

=head1 METHODS

=over 4

=item C<< new ( @triples ) >>

Returns a new BasicGraphPattern structure.

=cut

sub new {
	my $class	= shift;
	my @triples	= @_;
	foreach my $t (@triples) {
		unless (blessed($t) and $t->isa('RDF::Trine::Statement')) {
			throw RDF::Trine::Error -text => "Patterns belonging to a BGP must be triples";
		}
	}
	return bless( [ @triples ], $class );
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

=item C<< type >>

=cut

sub type {
	return 'BGP';
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(bgp %s)',
		join(' ', map { $_->sse( $context ) } $self->triples)
	);
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->referenced_variables } $self->triples);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->definite_variables } $self->triples);
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( map { $_->clone } $self->triples );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	return $class->new( map { $_->bind_variables( $bound ) } $self->triples );
}

=item C<< subsumes ( $statement ) >>

Returns true if the pattern will subsume the $statement when matched against a
triple store.

=cut

sub subsumes {
	my $self	= shift;
	my $st		= shift;
	
	my $l		= Log::Log4perl->get_logger("rdf.trine.pattern");
	my @triples	= $self->triples;
	foreach my $t (@triples) {
		if ($t->subsumes( $st )) {
			$l->debug($self->sse . " \x{2292} " . $st->sse);
			return 1;
		}
	}
	return 0;
}

=item C<< sort_for_join_variables >>

Returns a new pattern object with the subpatterns of the referrant sorted so
that they may be joined in order while avoiding cartesian products (if possible).

=cut

sub sort_for_join_variables {
	my $self	= shift;
	my $class	= ref($self);
	my @triples	= $self->triples;
	my %triples_by_tid;
	foreach my $t (@triples) {
		$triples_by_tid{ refaddr($t) }	= $t;
	}
	
	my %triples_with_variable;
	foreach my $t (@triples) {
		my $tid	= refaddr($t);
		foreach my $n ($t->nodes) {
			if ($n->isa('RDF::Trine::Node::Variable')) {
				my $var	= $n->name;
				$triples_with_variable{ $var }{ $tid }++;
			}
		}
	}
	foreach my $var (keys %triples_with_variable) {
		my @tids	= sort { $a <=> $b } keys %{ $triples_with_variable{ $var } };
		$triples_with_variable{ $var }	= \@tids;
	}
	
	my %variables_in_triple;
	foreach my $var (keys %triples_with_variable) {
		foreach my $tid (@{ $triples_with_variable{ $var } }) {
			$variables_in_triple{ $tid }{ $var }++;
		}
	}
	foreach my $tid (keys %variables_in_triple) {
		my @vars	= sort keys %{ $variables_in_triple{ $tid } };
		$variables_in_triple{ $tid }	= \@vars;
	}
	
	my %used_vars;
	my %used_tids;
	my @sorted;
	my $first	= shift(@triples);	# start with the first triple in syntactic order
	push(@sorted, $first);
	$used_tids{ refaddr($first) }++;
	foreach my $var (@{ $variables_in_triple{ refaddr($first) } }) {
		$used_vars{ $var }++;
	}
	while (@triples) {
		my @candidate_tids	= grep { not($used_tids{$_}) } map { @{ $triples_with_variable{ $_ } } } (keys %used_vars);
		last unless scalar(@candidate_tids);
		my $next_id	= shift(@candidate_tids);
		my $next	= $triples_by_tid{ $next_id };
		push(@sorted, $next);
		$used_tids{ refaddr($next) }++;
		foreach my $var (@{ $variables_in_triple{ refaddr($next) } }) {
			$used_vars{ $var }++;
		}
		@triples	= grep { refaddr($_) != $next_id } @triples;
	}
	push(@sorted, @triples);
	return $class->new(@sorted);
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
