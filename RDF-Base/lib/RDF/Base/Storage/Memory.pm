# RDF::Base::Storage::Memory
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Storage::Memory - [One line description of module's purpose here]


=head1 VERSION

This document describes RDF::Base::Storage::Memory version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Storage::Memory;
    $storage = RDF::Base::Storage::Memory->new();
    
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=cut

package RDF::Base::Storage::Memory;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Base::Storage);

use Carp;
use Scalar::Util qw(blessed refaddr);
use RDF::SPARQLResults::Graph;

# Module implementation here

=head1 METHODS

=over 4

=cut

=item C<< new >>

Returns a new memory-based RDF storage object.

=cut

sub new {
	my $class	= shift;
	my $self	= {
					triples	=> {},
					subj	=> {},
					pred	=> {},
					obj		=> {},
					context	=> {},
				};
	
	bless( $self, $class );
}

=item C<< add_statement ( $statement ) >>

=item C<< add_statement ( $subject, $predicate, $object ) >>

Adds the specified statement to the stored RDF graph.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub add_statement {
	my $self		= shift;
	my ($st, $s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		$st		= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
		$st		= RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o, context => $c );
	}
	
	my $addr	= $st->as_string;
	my @addr	= map { blessed($_) ? $_->as_sparql : '' } ($s, $p, $o, $c);
	my %addr;
	@addr{ qw(s p o c) }	= @addr;
	
	$self->{ triples }{ $addr }					= $st;
	$self->{ subj }{ $addr{ 's' } }{ $addr }	= $st;
	$self->{ pred }{ $addr{ 'p' } }{ $addr }	= $st;
	$self->{ obj }{ $addr{ 'o' } }{ $addr }		= $st;
	$self->{ context }{ $addr{ 'c' } }{ $addr }	= $st;
	return 1;
}

=item C<< remove_statement ( $statement ) >>

=item C<< remove_statement ( $subject, $predicate, $object ) >>

Removes the specified statement from the stored RDF graph.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub remove_statement {
	my $self		= shift;
	my ($st, $s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		$st		= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
		$st		= RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o, context => $c );
	}
	
	my $addr	= $st->as_string;
	my @addr	= map { blessed($_) ? $_->as_sparql : '' } ($s, $p, $o, $c);
	my %addr;
	@addr{ qw(s p o c) }	= @addr;
	
	delete $self->{ triples }{ $addr };
	delete $self->{ subj }{ $addr{ 's' } }{ $addr };
	delete $self->{ pred }{ $addr{ 'p' } }{ $addr };
	delete $self->{ obj }{ $addr{ 'o' } }{ $addr };
	delete $self->{ context }{ $addr{ 'c' } }{ $addr };
	return 1;
}

=item C<< exists_statement ( $statement ) >>

=item C<< exists_statement ( $subject, $predicate, $object ) >>

Returns true if the specified statement exists in the stored RDF graph.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub exists_statement {
	my $self	= shift;
	my ($st, $s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		$st		= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
		$st		= RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o, context => $c );
	}
	
	foreach my $triple (values %{ $self->{'triples'} }) {
		if ($st->equal( $triple )) {
			return 1;
		}
	}
	return 0;
}

=item C<< count_statements ( $statement ) >>

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns the number of matching statement that exists in the stored RDF graph.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be RDF::Node objects.

=cut

sub count_statements {
	my $self	= shift;
	my ($s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
	}
	
	my $count	= 0;
	my %match	= map { @$_ } grep { defined($_->[1]) } ( [ subject => $s ], [ predicate => $p ], [ object => $o ], [ context => $c ] );
	TRIPLES: foreach my $triple (values %{ $self->{'triples'} }) {
		foreach my $method (keys %match) {
			my $value	= $match{ $method };
			next TRIPLES unless ($triple->$method()->equal( $value ));
		}
		$count++;
	}
	
	return $count;
}

=item C<< get_statements ( $statement ) >>

=item C<< get_statements ( $subject, $predicate, $object, $context ) >>

Returns an iterator object of all statements matching the specified statement.
C<$statement> must be a RDF::Statement object.
C<$subject>, C<$predicate>, and C<$object> must be either undef (to match any node)
or RDF::Node objects.

=cut

sub get_statements {
	my $self	= shift;
	my ($s, $p, $o, $c);
	if (blessed($_[0]) and $_[0]->isa('RDF::Base::Statement')) {
		my $st	= shift;
		$s		= $st->subject;
		$p		= $st->predicate;
		$o		= $st->object;
		$c		= $st->context;
	} else {
		$s		= shift;
		$p		= shift;
		$o		= shift;
		$c		= shift;
	}

	
	my @triples	= (values %{ $self->{'triples'} });
	my %match	= map { @$_ } grep { defined($_->[1]) } ( [ subject => $s ], [ predicate => $p ], [ object => $o ], [ context => $c ] );
	
	my $stream	= RDF::SPARQLResults::Graph->new( sub {
		TRIPLES: while (my $triple = shift(@triples)) {
			foreach my $method (keys %match) {
				my $value	= $match{ $method };
				my $obj		= $triple->$method();
				next TRIPLES unless (blessed($obj) and $obj->equal( $value ));
			}
			return $triple;
		}
		return;
	} );
	
	return $stream;
}





=begin private

=item C<< meta >>

Moose metaclass accessor.

=end private

=cut



1; # Magic true value required at end of module
__END__

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
RDF::Base::Storage::Memory requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


