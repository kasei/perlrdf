# RDF::Query::Algebra::Optional
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Optional - Algebra class for Optional patterns

=cut

package RDF::Query::Algebra::Optional;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.002';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, $opt_pattern )>

Returns a new Optional structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $opt		= shift;
	return bless( [ 'OPTIONAL', $pattern, $opt ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->pattern, $self->optional);
}

=item C<< pattern >>

Returns the base pattern (LHS) onto which the optional pattern joins.

=cut

sub pattern {
	my $self	= shift;
	return $self->[1];
}

=item C<< optional >>

Returns the optional pattern (RHS).

=cut

sub optional {
	my $self	= shift;
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(leftjoin %s %s)',
		$self->pattern->sse( $context ),
		$self->optional->sse( $context )
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $string	= sprintf(
		"%s\n${indent}OPTIONAL %s",
		$self->pattern->as_sparql( $context, $indent ),
		$self->optional->as_sparql( $context, $indent ),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'OPTIONAL';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq($self->pattern->referenced_variables, $self->optional->referenced_variables);
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
		return $class->new( map { $_->fixup( $query, $bridge, $base, $ns ) } ($self->pattern, $self->optional) );
	}
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
	
	my $data_triples	= $self->pattern;
	my $opt_triples		= $self->optional;
	
	my $dstream		= $data_triples->execute( $query, $bridge, $bound, $context, %args );
	
	my @names		= uniq( map { $_->referenced_variables } ($data_triples, $opt_triples) );
	my @results;
	while (my $rowa = $dstream->next) {
		my %obound	= (%$bound, %$rowa);
		my $ostream	= $opt_triples->execute( $query, $bridge, \%obound, $context, %args );
#		warn 'OPTIONAL ALREADY BOUND: ' . Dumper(\%obound, $opt_triples);
		
		my $count	= 0;
		while (my $rowb = $ostream->next) {
			$count++;
# 			warn "OPTIONAL JOINING: (" . join(', ', keys %$rowa) . ") JOIN (" . join(', ', keys %$rowb) . ")\n";
			my %keysa	= map {$_=>1} (keys %$rowa);
			my @shared	= grep { $keysa{ $_ } } (keys %$rowb);
#			@names		= @shared unless (@names);
			my $ok		= 1;
			foreach my $key (@shared) {
				my $val_a	= $rowa->{ $key };
				my $val_b	= $rowb->{ $key };
				unless ($bridge->equals($val_a, $val_b)) {
# 					warn "can't join because mismatch of $key (" . join(' <==> ', map {$bridge->as_string($_)} ($val_a, $val_b)) . ")" if ($debug);
					$ok	= 0;
					last;
				}
			}
			
			if ($ok) {
				my $row	= { %$rowa, %$rowb };
# 				warn "JOINED:\n";
# 				foreach my $key (keys %$row) {
# 					warn "$key\t=> " . $bridge->as_string( $row->{ $key } ) . "\n";
# 				}
				push(@results, $row);
			} else {
				push(@results, $rowa);
			}
		}
		
		unless ($count) {
#################### XXXXXXXXXXXXXXXXXXXXXXXXX								
#			warn "[optional] didn't return any results. passing through outer result: " . Dumper($rowa);
			push(@results, $rowa);
		}
	}
	
	my $stream	= RDF::Trine::Iterator::Bindings->new( \@results, \@names );
	$stream	= swatch {
		my $row	= $_;
#		warn "[OPTIONAL] " . join(', ', map { join('=',$_,$bridge->as_string($row->{$_})) } (keys %$row)) . "\n";
	} $stream;
	return $stream;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
