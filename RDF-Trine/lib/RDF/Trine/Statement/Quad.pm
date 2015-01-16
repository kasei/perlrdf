# RDF::Trine::Statement::Quad
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Statement::Quad - Class for quads and quad patterns

=head1 VERSION

This document describes RDF::Trine::Statement::Quad version 1.012

=cut

package RDF::Trine::Statement::Quad;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Statement);

use Scalar::Util qw(blessed);
use Carp qw(croak);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Statement> class.

=over 4

=cut

=item C<new ( $s, $p, $o, $c )>

Returns a new Quad structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	unless (scalar(@nodes) == 4) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Quad constructor must have four node arguments";
	}
	my @names	= qw(subject predicate object context);
	foreach my $i (0 .. 3) {
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
	return @$self;
}

=item C<< node_names >>

Returns the method names for accessing the nodes of this statement.

=cut

sub node_names {
	return qw(subject predicate object context);
}

=item C<< graph >>

=item C<< context >>

Returns the graph node of the quad pattern.

=cut

sub context {
	my $self	= shift;
	if (@_) {
		$self->[3]	= shift;
	}
	return $self->[3];
}
*graph	= \&context;

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	my @nodes	= $self->nodes;
	my @sse		= map { $_->sse( $context ) } (@nodes);
	return sprintf( '(quad %s %s %s %s)', @sse );
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

=item C<< from_redland ( $statement, $name ) >>

Given a RDF::Redland::Statement object and a graph name, returns a perl-native
RDF::Trine::Statement::Quad object.

=cut

sub from_redland {
	my $self	= shift;
	my $rstmt	= shift;
	my $graph	= shift;
	
	my $rs		= $rstmt->subject;
	my $rp		= $rstmt->predicate;
	my $ro		= $rstmt->object;
	
	my $cast	= sub {
		my $node	= shift;
		my $type	= $node->type;
		if ($type == $RDF::Redland::Node::Type_Resource) {
			return RDF::Trine::Node::Resource->new( $node->uri->as_string );
		} elsif ($type == $RDF::Redland::Node::Type_Blank) {
			return RDF::Trine::Node::Blank->new( $node->blank_identifier );
		} elsif ($type == $RDF::Redland::Node::Type_Literal) {
			my $lang	= $node->literal_value_language;
			my $dturi	= $node->literal_datatype;
			my $dt		= ($dturi)
						? $dturi->as_string
						: undef;
			return RDF::Trine::Node::Literal->new( $node->literal_value, $lang, $dt );
		} else {
			croak 'Unknown node type in statement conversion';
		}
	};
	
	my @nodes;
	foreach my $n ($rs, $rp, $ro) {
		push(@nodes, $cast->( $n ));
	}
	my $st	= $self->new( @nodes, $graph );
	return $st;
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
