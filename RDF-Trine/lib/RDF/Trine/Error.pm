# RDF::Trine::Error
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Error - Error classes for RDF::Trine

=head1 VERSION

This document describes RDF::Trine::Error version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Error qw(:try);

=head1 DESCRIPTION

RDF::Trine::Error provides a class hierarchy of errors that other RDF::Trine
classes may throw using the L<Error|Error> API. See L<Error> for more
information.

=head1 REQUIRES

L<Error|Error>

=cut

package RDF::Trine::Error;

use strict;
use warnings;
no warnings 'redefine';
use Carp qw(carp croak confess);

use base qw(Error);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

package RDF::Trine::Error::CompilationError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::QuerySyntaxError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::MethodInvocationError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::SerializationError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::DatabaseError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::ParserError;

use base qw(RDF::Trine::Error);

package RDF::Trine::Error::ParserError::Explainable;

use base qw(RDF::Trine::Error::ParserError);
use Module::Load::Conditional qw[can_load];

our $ANSI;
BEGIN {
	$ANSI	= can_load( modules => { 'Term::ANSIColor' => undef } );
}

sub _get_line {
	my $self	= shift;
	my $fh		= shift;
	my $line	= shift;
	my $buffer;
	do {
		$buffer	= $fh->getline;
	} while (--$line);
	return $buffer;
}

package RDF::Trine::Error::ParserError::Tokenized;

use base qw(RDF::Trine::Error::ParserError::Explainable);

sub explain {
	my $self	= shift;
	my $fh		= shift;
	seek($fh, 0, 0);
	my $text	= $self->text;
	my $t		= $self->object;
	my $line	= $t->start_line;
	my $col		= $t->start_column;
	my $buffer	= $self->_get_line( $fh, $line );
	my $maxlen	= length($buffer) - $col;
	my $len		= 1;
	if ($t->line == $t->start_line) {
		$len	= ($t->column - $t->start_column);
	} else {
		$len	= $maxlen;
	}
	
	my $tabs	= ($buffer =~ tr/\t//);
	$buffer		=~ s/\t/    /g;
	$col		+= 3 * $tabs;
	
	chomp($text);
	
	if ($RDF::Trine::Error::ParserError::Explainable::ANSI) {
		print STDERR Term::ANSIColor::color('red');
		print STDERR "$text:\n";
		print STDERR Term::ANSIColor::color('reset');
		print STDERR substr($buffer, 0, $col-1);
		print STDERR Term::ANSIColor::color('red');
		print STDERR substr($buffer, $col-1, $len);
		print STDERR Term::ANSIColor::color('reset');
		print STDERR substr($buffer, $col+$len-1);
		print STDERR " " x ($col-1);
		print STDERR Term::ANSIColor::color('blue');
		print STDERR "^";
		if ($len > 1) {
			print STDERR ("~" x ($len-1));
		}
		print STDERR "\n";
		print STDERR Term::ANSIColor::color('reset');
	} else {
		print STDERR "$text:\n";
		print STDERR $buffer;
		print STDERR " " x ($col-1);
		print STDERR "^";
		if ($len > 1) {
			print STDERR ("~" x ($len-1));
		}
		print STDERR "\n";
	}
}

package RDF::Trine::Error::ParserError::Positioned;

use base qw(RDF::Trine::Error::ParserError::Explainable);

sub explain {
	my $self	= shift;
	my $fh		= shift;
	seek($fh, 0, 0);
	my $text	= $self->text;
	my $pos		= $self->value;
	my ($line, $col)	= @$pos;
	my $buffer	= $self->_get_line( $fh, $line ) || '';
	
	my $tabs	= ($buffer =~ tr/\t//);
	$buffer		=~ s/\t/    /g;
	$col		+= 3 * $tabs;
	
	chomp($text);
	
	if ($RDF::Trine::Error::ParserError::Explainable::ANSI) {
		print STDERR Term::ANSIColor::color('red');
		print STDERR "$text:\n";
		print STDERR Term::ANSIColor::color('reset');
		print STDERR $buffer;
		print STDERR Term::ANSIColor::color('red');
		print STDERR " " x ($col-1);
		print STDERR "^";
		print STDERR Term::ANSIColor::color('reset');
		print STDERR "\n";
	} else {
		print STDERR "$text:\n";
		print STDERR $buffer;
		print STDERR " " x ($col-1);
		print STDERR "^";
		print STDERR "\n";
	}
}

package RDF::Trine::Error::UnimplementedError;

use base qw(RDF::Trine::Error);

1;

__END__

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
