package RDF::Trine::Parser::Turtle::Constants;

use strict;
use warnings;
use 5.014;

our @EXPORT;
BEGIN {
	@EXPORT = qw(
		LBRACKET
		RBRACKET
		LPAREN
		RPAREN
		DOT
		SEMICOLON
		COMMA
		HATHAT
		A
		BOOLEAN
		PREFIXNAME
		IRI
		BNODE
		DOUBLE
		DECIMAL
		INTEGER
		WS
		COMMENT
		STRING3D
		STRING1D
		BASE
		PREFIX
		LANG
		LBRACE
		RBRACE
		EQUALS
		decrypt_constant
	)
};
use base 'Exporter';

{
	my %mapping;
	my %reverse;
	BEGIN {
		my $cx	= 0;
		foreach my $name (grep { $_ ne 'decrypt_constant' } @EXPORT) {
			my $value	= ++$cx;
			$reverse{ $value }	= $name;
			$mapping{ $name }	= $value;
		}
	}
	use constant +{ %mapping };
	sub decrypt_constant { my $num	= +shift; $reverse{$num} }
};

1;
