# RDF::Trine::Parser::LineProtocol
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::LineProtocol - RDF LineProtocol Parser

=head1 VERSION

This document describes RDF::Trine::Parser::LineProtocol version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser::LineProtocol;
 my $serializer	= RDF::Trine::Parser::LineProtocol->new();

=head1 DESCRIPTION

The RDF::Trine::Parser::LineProtocol class provides
A line-based protocol for querying and updating triple/quad stores.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::LineProtocol;

use strict;
use warnings;
use Scalar::Util qw(blessed);
use base qw(RDF::Trine::Parser::RDFPatch);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

=item C<< handle_op ( $op, $handler, $lineno ) >>

Handles the RDF::Trine::Parser::RDFPatch::Op operation object.
For 'A'dd operations, the C<< $handler >> callback is called with the RDF statement.
Otherwise an exception is thrown.

=cut

sub handle_op {
	my $self	= shift;
	my $op		= shift;
	my $handler	= shift;
	my $lineno	= shift;
	my $opid	= $op->op;
	if ($opid eq 'F') {
		# no-op
	} else {
		return $self->SUPER::handle_op( $op, $handler, $lineno );
	}
}

=item C<< parse_line ( $line, $base ) >>

Parses the Line Protocol string C<< $line >> and returns the corresponding
L<RDF::Trine::Parser::RDFPatch::Op> object.

=cut

sub parse_line {
	my $self	= shift;
	my $line	= shift;
	my $base	= shift;
	
	my ($op, $tail)	= split(/ /, $line, 2);
	my $p		= RDF::Trine::Parser::Turtle->new( 'map' => $self->{namespaces} );
	if ($op =~ /^[QF]$/) {
		my @nodes;
		foreach my $pos (1,2,3,4) {
			if ($tail =~ /^\s*U\b/) {
				substr($tail, 0, $+[0], '');
				my $v	= RDF::Trine::Node::Variable->new("v$pos");
				$self->{last}[$pos]	= $v;
				push(@nodes, $v);
			} elsif ($tail =~ /^\s*R\b/) {
				substr($tail, 0, $+[0], '');
				my $node	= $self->{last}[$pos];
				unless (blessed($node)) {
					throw RDF::Trine::Error -text => "Use of non-existent `R`epeated term";
				}
				push(@nodes, $node);
			} elsif ($tail =~ /^\s*[.]/) {
				last;
			} else {
				my $token;
				my $n	= $p->parse_node($tail, $base, token => \$token);
				$self->{last}[$pos]	= $n;
				push(@nodes, $n);
				my $len	= $token->column;
				substr($tail, 0, $len, '');
			}
		}
		
		my @args;
		if (scalar(@nodes) == 3) {
			@args	= RDF::Trine::Statement->new(@nodes);
		} elsif (scalar(@nodes) == 4) {
			@args	= RDF::Trine::Statement::Quad->new(@nodes);
		} else {
			@args	= @nodes;
		}
	
		return RDF::Trine::Parser::RDFPatch::Op->new( $op, @args );
	} else {
		return $self->SUPER::parse_line( $line, $base );
	}
}

=item C<< execute_line ( $line, $model, $out ) >>

Parses the Line Protocol string C<< $line >> and executes the parsed operation using
the supplied C<< $model >>. If the operation returns results (in the case of a
Query operation), they are printed to the C<< $out >> file handle.

=cut

sub execute_line {
	my $self	= shift;
	my $line	= shift;
	my $model	= shift;
	my $out		= shift;
	
	return unless ($line =~ /^\S/);
	if ($line =~ /[?]/) {
		print $out $model->as_string;
		return;
	}
	
	my $op		= $self->parse_line($line);
	return unless ($op and blessed($op));
	my $map		= $self->namespace_map;
	if ($op->op =~ /^[AD]$/) {
		$op->execute( $model );
	} elsif ($op->op eq 'Q') {
		my $iter	= $op->execute( $model );
		my $s		= RDF::Trine::Serializer::Turtle->new( namespaces => $map );
		while (my $st = $iter->next) {
			my @nodes	= $st->nodes;
			print $out join(' ', 'A', map { $s->serialize_node($_) } @nodes) . " .\n";
		}
		print $out "F .\n";
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://afs.github.io/rdf-patch/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
