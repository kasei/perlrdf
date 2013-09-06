# RDF::Trine::Parser::RDFPatch
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFPatch - RDF-Patch Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFPatch version 1.007

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

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.007';
}

######################################################################

=item C<< new (  ) >>

Returns a new RDF-Patch Parser object.

=cut

sub new {
	my $class	= shift;
	my $self = bless( {}, $class );
	return $self;
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
	
	...
}

=item C<< parse_line ( $line, $base ) >>

Returns an operation object.

=cut

sub parse_line {
	my $self	= shift;
	my $line	= shift;
	my $base	= shift;
	my ($op, $tail)	= split(/ /, $line, 2);
	my $p		= RDF::Trine::Parser::Turtle->new();
	my @nodes;
	foreach my $pos (1,2,3,4) {
		if ($tail =~ /^\s*U\b/) {
			substr($tail, 0, $+[0], '');
			push(@nodes, RDF::Trine::Node::Variable->new("v$pos"));
		} elsif ($tail =~ /^\s*[.]/) {
			last;
		} else {
			my $token;
			push(@nodes, $p->parse_node($tail, $base, token => \$token));
# 			warn ">> removing $len chars";
# 			warn "before: <<$tail>>\n";
			my $len	= $token->column;
			substr($tail, 0, $len, '');
# 			warn "after : <<$tail>>\n";
		}
	}
	
	my $st;
	if (scalar(@nodes) == 3) {
		$st	= RDF::Trine::Statement->new(@nodes);
	} elsif (scalar(@nodes) == 4) {
		$st	= RDF::Trine::Statement::Quad->new(@nodes);
	}
	
	if ($st and $op eq 'A' or $op eq 'D' or $op eq 'Q') {
# 		warn '### ' . $st->as_string;
		return RDF::Trine::Parser::RDFPatch::Op->new( $op, $st );
	} else {
		die "Unknown op '$op'";
	}
}


package RDF::Trine::Parser::RDFPatch::Op;

use strict;
use warnings;

=item C<< new (  ) >>

Returns a new RDF-Patch Parser object.

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
	if ($self->op eq 'A') {
		return $model->add_statement( $self->args );
	} elsif ($self->op eq 'D') {
		return $model->remove_statement( $self->args );
	} elsif ($self->op eq 'Q') {
		my ($st)	= $self->args;
		return $model->get_statements( $st->nodes );
	} else {
		die "unimplemented op";
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
