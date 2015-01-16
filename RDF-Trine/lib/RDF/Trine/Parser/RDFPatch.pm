# RDF::Trine::Parser::RDFPatch
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFPatch - RDF-Patch Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFPatch version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser::RDFPatch;
 my $serializer	= RDF::Trine::Parser::RDFPatch->new();

=head1 DESCRIPTION

The RDF::Trine::Parser::RDFPatch class provides an API for serializing RDF
graphs to the RDF-Patch syntax.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::RDFPatch;

use strict;
use warnings;

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use List::Util qw(min);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);
use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::Turtle::Constants;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

=item C<< new (  ) >>

Returns a new RDF-Patch Parser object.

=cut

sub new {
	my $class	= shift;
	my $self = bless( {
		last		=> [],
		namespaces	=> RDF::Trine::NamespaceMap->new(),
	}, $class );
	return $self;
}

=item C<< namespace_map >>

Returns the RDF::Trine::NamespaceMap object used in parsing.

=cut

sub namespace_map {
	my $self	= shift;
	return $self->{namespaces};
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;
	open( my $fh, '<:encoding(UTF-8)', \$string );
	return $self->parse_file( $base, $fh, $handler );
}

=item C<< parse_file ( $base, $fh, \&handler ) >>

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;
	
	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		open( $fh, '<:encoding(UTF-8)', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	my $lineno	= 0;
	while (defined(my $line = <$fh>)) {
		$lineno++;
		my $op	= $self->parse_line( $line, $base );
		last unless blessed($op);
		$self->handle_op( $op, $handler, $lineno );
	}
}

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
	if ($opid eq 'A') {
		my ($st)	= $op->args;
		$handler->( $st );
	} else {
		my $col	= 0;
		throw RDF::Trine::Error::ParserError::Positioned (
			-text => "Cannot handle RDF Patch operation type '$opid' during RDF parsing at $lineno:$col",
			-value => [$lineno, $col],
		);
	}
}

=item C<< parse_line ( $line, $base ) >>

Returns an operation object.

=cut

sub _get_token_type {
	my $self	= shift;
	my $l		= shift;
	my $type	= shift;
	my $t		= $l->get_token;
	unless ($t) {
		$l->_throw_error(sprintf("Expecting %s but got EOF", decrypt_constant($type)));
		return;
	}
	unless ($t->type eq $type) {
		$self->_throw_error(sprintf("Expecting %s but got %s", decrypt_constant($type), decrypt_constant($t->type)), $t, $l);
	}
	return $t;
}

sub parse_line {
	my $self	= shift;
	my $line	= shift;
	my $base	= shift;
	return if ($line =~ /^#/);
	if (substr($line, 0, 7) eq '@prefix') {
		open( my $fh, '<:encoding(UTF-8)', \$line );
		my $l	= RDF::Trine::Parser::Turtle::Lexer->new($fh);
		$self->_get_token_type($l, PREFIX);
		my $t	= $self->_get_token_type($l, PREFIXNAME);
		my $name	= $t->value;
		$name		=~ s/:$//;
		$t	= $self->_get_token_type($l, IRI);
		my $r	= RDF::Trine::Node::Resource->new($t->value, $base);
		my $iri	= $r->uri_value;
		$t	= $self->_get_token_type($l, DOT);
		$self->{namespaces}->add_mapping( $name => $iri );
		return;
	}
	
	my ($op, $tail)	= split(/ /, $line, 2);
	unless ($op =~ /^[ADQ]$/) {
		throw RDF::Trine::Error::ParserError -text => "Unknown RDF Patch operation ID '$op'";
	}
	
	my $p		= RDF::Trine::Parser::Turtle->new( 'map' => $self->{namespaces} );
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
	
	my $st;
	if (scalar(@nodes) == 3) {
		$st	= RDF::Trine::Statement->new(@nodes);
	} elsif (scalar(@nodes) == 4) {
		$st	= RDF::Trine::Statement::Quad->new(@nodes);
	} else {
		my $arity	= scalar(@nodes);
		throw RDF::Trine::Error::ParserError -text => "RDFPatch operation '$op' has unexpected arity ($arity)";
	}
	
	return RDF::Trine::Parser::RDFPatch::Op->new( $op, $st );
}


package RDF::Trine::Parser::RDFPatch::Op;

use strict;
use warnings;

=item C<< new ( $op, @args ) >>

Returns a new RDF-Patch Parser operation object.

=cut

sub new {
	my $class	= shift;
	my $op		= shift;
	my @args	= @_;
	my $self = bless( { op => $op, args => \@args }, $class );
	return $self;
}

sub op {
	my $self	= shift;
	return $self->{op};
}

sub args {
	my $self	= shift;
	return @{ $self->{args} };
}

sub execute {
	my $self	= shift;
	my $model	= shift;
	my $op	= $self->op;
	if ($op eq 'A') {
		return $model->add_statement( $self->args );
	} elsif ($op eq 'D') {
		return $model->remove_statement( $self->args );
	} elsif ($op eq 'Q') {
		my ($st)	= $self->args;
		return $model->get_statements( $st->nodes );
	} else {
		throw RDF::Trine::Error -text => "Unexpected operation '$op' in RDF::Trine::Parser::RDFPatch::Op->execute";
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
