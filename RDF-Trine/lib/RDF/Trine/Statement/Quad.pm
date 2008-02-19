# RDF::Trine::Statement::Quad
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Statement::Quad - Algebra class for Triple patterns

=cut

package RDF::Trine::Statement::Quad;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Statement);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $s, $p, $o, $c )>

Returns a new Quad structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	Carp::confess "Quad constructor must have four node arguments" unless (scalar(@nodes) == 4);
	my @names	= qw(subject predicate object context);
	foreach my $i (0 .. 2) {
		unless (defined($nodes[ $i ])) {
			$nodes[ $i ]	= RDF::Trine::Node::Variable->new($names[ $i ]);
		}
	}
	
	return bless( [ @nodes ], $class );
}

=item C<< nodes >>

Returns the subject, predicate and object of the triple pattern.

=cut

sub nodes {
	my $self	= shift;
	my $s		= $self->subject;
	my $p		= $self->predicate;
	my $o		= $self->object;
	my $c		= $self->context;
	return ($s, $p, $o, $c);
}

=item C<< context >>

Returns the context node of the quad pattern.

=cut

sub context {
	my $self	= shift;
	if (@_) {
		$self->[3]	= shift;
	}
	return $self->[3];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	return sprintf(
		'(quad %s %s %s %s)',
		$self->subject->sse( $context ),
		$self->predicate->sse( $context ),
		$self->object->sse( $context ),
		$self->context->sse( $context ),
	);
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'QUAD';
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( $self->nodes );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
