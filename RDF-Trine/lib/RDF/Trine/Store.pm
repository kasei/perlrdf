# RDF::Trine::Store
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Store - RDF triplestore base class

=head1 VERSION

This document describes RDF::Trine::Store version 0.112_02

=cut

package RDF::Trine::Store;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);

use RDF::Trine::Store::DBI;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.112_02';
}

######################################################################

=head1 METHODS

=over 4

=cut


=item C<< temporary_store >>

Returns a new temporary triplestore (using appropriate default values).

=cut

sub temporary_store {
	return RDF::Trine::Store::DBI->temporary_store();
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	die "unimplemented";
}

=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
	my $self	= shift;
	my $bgp		= shift;
	my $context	= shift;
	my @args	= @_;
	
	my @triples	= $bgp->triples;
	if (1 == scalar(@triples)) {
		my $t		= shift(@triples);
		my @nodes	= $t->nodes;
		my %vars;
		my @names	= qw(subject predicate object);
		foreach my $n (0 .. 2) {
			if ($nodes[$n]->isa('RDF::Trine::Node::Variable')) {
				$vars{ $names[ $n ] }	= $nodes[$n]->name;
			}
		}
		my $iter	= $self->get_statements( @nodes, $context, @args );
		my @vars	= values %vars;
		my $sub		= sub {
			my $row	= $iter->next;
			return undef unless ($row);
			my %data	= map { $vars{ $_ } => $row->$_() } (keys %vars);
			return \%data;
		};
		return RDF::Trine::Iterator::Bindings->new( $sub, \@vars );
	} else {
		my $t		= shift(@triples);
		my $rhs	= $self->get_pattern( RDF::Trine::Pattern->new( $t ), $context, @args );
		my $lhs	= $self->get_pattern( RDF::Trine::Pattern->new( @triples ), $context, @args );
		my @inner;
		while (my $row = $rhs->next) {
			push(@inner, $row);
		}
		my @results;
		while (my $row = $lhs->next) {
			RESULT: foreach my $irow (@inner) {
				my %keysa;
				my @keysa	= keys %$irow;
				@keysa{ @keysa }	= (1) x scalar(@keysa);
				my @shared	= grep { exists $keysa{ $_ } } (keys %$row);
				foreach my $key (@shared) {
					my $val_a	= $irow->{ $key };
					my $val_b	= $row->{ $key };
					next unless (defined($val_a) and defined($val_b));
					my $equal	= $val_a->equal( $val_b );
					unless ($equal) {
						next RESULT;
					}
				}
				
				my $jrow	= { (map { $_ => $irow->{$_} } grep { defined($irow->{$_}) } keys %$irow), (map { $_ => $row->{$_} } grep { defined($row->{$_}) } keys %$row) };
				push(@results, $jrow);
			}
		}
		return RDF::Trine::Iterator::Bindings->new( \@results, [ $bgp->referenced_variables ] );
	}
}

=item C<< get_contexts >>

=cut

sub get_contexts {
	die "unimplemented";
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	die "unimplemented";
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	die "unimplemented";
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	die "unimplemented";
}

=item C<< count_statements ($subject, $predicate, $object) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	die "unimplemented";
}


1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

