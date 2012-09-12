package RDF::Trine::Parser::Turtle::Constants;

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
		decrypt_constant
	)
};
use base 'Exporter';

{
	my ($cx, %reverse) = 0;
	use constant +{
		map  { my $value = ++$cx; $reverse{$value} = $_; $_ => $value }
		grep { $_ ne 'decrypt_constant' }
		@EXPORT
	};
	sub decrypt_constant { $reverse{+shift} }
};

1;
