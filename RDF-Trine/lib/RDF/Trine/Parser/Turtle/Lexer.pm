# RDF::Trine::Parser::Turtle::Lexer
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::Turtle::Lexer - Tokenizer for parsing Turtle, TriG, and N-Triples

=head1 VERSION

This document describes RDF::Trine::Parser::Turtle::Lexer version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser::Lexer;
 my $l = RDF::Trine::Parser::Lexer->new( file => $fh );
 while (my $t = $l->get_token) {
   ...
 }

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::Turtle::Lexer;

use RDF::Trine::Parser::Turtle::Constants;
use 5.010;
use strict;
use warnings;
use Moose;
use Data::Dumper;
use RDF::Trine::Error;

our $VERSION;
BEGIN {
	$VERSION				= '1.012';
}

my $r_nameChar_extra		= qr'[-0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]'o;
my $r_nameStartChar_minus_underscore	= qr'[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]'o;
my $r_nameStartChar			= qr/[A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/;
my $r_nameChar				= qr/${r_nameStartChar}|[-0-9\x{b7}\x{0300}-\x{036f}\x{203F}-\x{2040}]/;
my $r_prefixName			= qr/(?:(?!_)${r_nameStartChar})(?:$r_nameChar)*/;
my $r_nameChar_test			= qr"(?:$r_nameStartChar|$r_nameChar_extra)";
my $r_double				= qr'[+-]?([0-9]+\.[0-9]*[eE][+-]?[0-9]+|\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)';
my $r_decimal				= qr'[+-]?(([0-9]+\.[0-9]+)|\.([0-9])+)';
my $r_integer				= qr'[+-]?[0-9]+';
my $r_PN_CHARS_U			= qr/[_A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/;
my $r_PN_CHARS				= qr"${r_PN_CHARS_U}|[-0-9\x{00B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]";
my $r_bnode_id				= qr"(?:${r_PN_CHARS_U}|[0-9])((${r_PN_CHARS}|[.])*${r_PN_CHARS})?";

my $r_PN_CHARS_BASE			= qr/([A-Z]|[a-z]|[\x{00C0}-\x{00D6}]|[\x{00D8}-\x{00F6}]|[\x{00F8}-\x{02FF}]|[\x{0370}-\x{037D}]|[\x{037F}-\x{1FFF}]|[\x{200C}-\x{200D}]|[\x{2070}-\x{218F}]|[\x{2C00}-\x{2FEF}]|[\x{3001}-\x{D7FF}]|[\x{F900}-\x{FDCF}]|[\x{FDF0}-\x{FFFD}]|[\x{10000}-\x{EFFFF}])/;
# my $r_PN_CHARS_U			= qr/([_]|${r_PN_CHARS_BASE})/;
# my $r_PN_CHARS				= qr/${r_PN_CHARS_U}|-|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]/;
my $r_PN_PREFIX				= qr/(${r_PN_CHARS_BASE}((${r_PN_CHARS}|[.])*${r_PN_CHARS})?)/;
my $r_PN_LOCAL_ESCAPED		= qr{(\\([-~.!&'()*+,;=/?#@%_\$]))|%[0-9A-Fa-f]{2}};
my $r_PN_LOCAL				= qr/((${r_PN_CHARS_U}|[:0-9]|${r_PN_LOCAL_ESCAPED})((${r_PN_CHARS}|${r_PN_LOCAL_ESCAPED}|[:.])*(${r_PN_CHARS}|[:]|${r_PN_LOCAL_ESCAPED}))?)/;
my $r_PN_LOCAL_BNODE		= qr/((${r_PN_CHARS_U}|[0-9])((${r_PN_CHARS}|[.])*${r_PN_CHARS})?)/;
my $r_PNAME_NS				= qr/((${r_PN_PREFIX})?:)/;
my $r_PNAME_LN				= qr/(${r_PNAME_NS}${r_PN_LOCAL})/;

has file => (
	is => 'ro',
	isa => 'FileHandle',
	required => 1,
);

has linebuffer => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has line => (
	is => 'rw',
	isa => 'Int',
	default => 1,
);

has column => (
	is => 'rw',
	isa => 'Int',
	default => 1,
);

has buffer => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has start_column => (
	is => 'rw',
	isa => 'Int',
	default => -1,
);

has start_line => (
	is => 'rw',
	isa => 'Int',
	default => -1,
);

sub BUILDARGS {
	my $class	= shift;
	if (scalar(@_) == 1) {
		return { file => shift };
	} else {
		return $class->SUPER::BUILDARGS(@_);
	}
}

=item C<< new_token ( $type, @values ) >>

Returns a new token with the given type and optional values, capturing the
current line and column of the input data.

=cut

sub new_token {
	my $self		= shift;
	my $type		= shift;
	my $start_line	= $self->start_line;
	my $start_col	= $self->start_column;
	my $line		= $self->line;
	my $col			= $self->column;
	return RDF::Trine::Parser::Turtle::Token->fast_constructor(
			$type,
			$start_line,
			$start_col,
			$line,
			$col,
			\@_,
		);
}

my %CHAR_TOKEN	= (
	'.'	=> DOT,
	';'	=> SEMICOLON,
	'['	=> LBRACKET,
	']'	=> RBRACKET,
	'('	=> LPAREN,
	')'	=> RPAREN,
	'{'	=> LBRACE,
	'}'	=> RBRACE,
	','	=> COMMA,
	'='	=> EQUALS,
);

my %METHOD_TOKEN	= (
# 	q[#]	=> '_get_comment',
	q[@]	=> '_get_keyword',
	q[<]	=> '_get_iriref',
	q[_]	=> '_get_bnode',
	q[']	=> '_get_single_literal',
	q["]	=> '_get_double_literal',
	q[:]	=> '_get_pname',
	(map {$_ => '_get_number'} (0 .. 9, '-', '+'))
);

=item C<< get_token >>

Returns the next token present in the input.

=cut

sub get_token {
	my $self	= shift;
	while (1) {
		unless (length($self->{buffer})) {
			$self->fill_buffer;
		}
# 		warn "getting token with buffer: " . Dumper($self->{buffer});
		my $c	= $self->_peek_char();
		return unless (defined($c) and length($c));
		
		$self->start_column( $self->column );
		$self->start_line( $self->line );
		
		if ($c eq '.' and $self->{buffer} =~ $r_decimal) {
			return $self->_get_number();
		}
		
		if (defined(my $name = $CHAR_TOKEN{$c})) { $self->_get_char; return $self->new_token($name); }
		elsif (defined(my $method = $METHOD_TOKEN{$c})) { return $self->$method() }
		elsif ($c eq '#') {
			# we're ignoring comment tokens, but we could return them here instead of falling through to the 'next':
			$self->_get_comment();
			next;
		}
		elsif ($c =~ /[ \r\n\t]/) {
			while (defined($c) and length($c) and $c =~ /[\t\r\n ]/) {
				$self->_get_char;
				$c		= $self->_peek_char;
			}
			
			# we're ignoring whitespace tokens, but we could return them here instead of falling through to the 'next':
# 			return $self->new_token(WS);
			next;
		}
		elsif ($c =~ /[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/) {
			if ($self->{buffer} =~ /^a(?!:)\s/) {
				$self->_get_char;
				return $self->new_token(A);
			} elsif ($self->{buffer} =~ /^(?:true|false)(?!:)\b/) {
				my $bool	= $self->_read_length($+[0]);
				return $self->new_token(BOOLEAN, $bool);
			} elsif ($self->{buffer} =~ /^BASE(?!:)\b/i) {
				$self->_read_length(4);
				return $self->new_token(SPARQLBASE);
			} elsif ($self->{buffer} =~ /^PREFIX(?!:)\b/i) {
				$self->_read_length(6);
				return $self->new_token(SPARQLPREFIX);
			} else {
				return $self->_get_pname;
			}
		}
		elsif ($c eq '^') { $self->_read_word('^^'); return $self->new_token(HATHAT); }
		else {
# 			Carp::cluck sprintf("Unexpected byte '$c' (0x%02x)", ord($c));
			return $self->_throw_error(sprintf("Unexpected byte '%s' (0x%02x)", $c, ord($c)));
		}
		warn 'byte: ' . Dumper($c);
	}
}

=begin private

=cut

=item C<< fill_buffer >>

Fills the internal parse buffer with a new line from the input source.

=cut

sub fill_buffer {
	my $self	= shift;
	unless (length($self->buffer)) {
		my $line	= $self->file->getline;
		if (defined($line)) {
			$self->{buffer}	.= $line;
		}
	}
}

=item C<< check_for_bom >>

Checks the input buffer for a Unicode BOM, and consumes it if it is present.

=cut

sub check_for_bom {
	my $self	= shift;
	my $c	= $self->_peek_char();
	if (defined($c) and $c eq "\x{FEFF}") {
		$self->_get_char;
	}
}

sub _get_char_safe {
	my $self	= shift;
	my $char	= shift;
	my $c		= $self->_get_char;
	if ($c ne $char) {
		$self->_throw_error("Expected '$char' but got '$c'");
	}
	return $c;
}

sub _get_char_fill_buffer {
	my $self	= shift;
	if (length($self->{buffer}) == 0) {
		$self->fill_buffer;
		if (length($self->{buffer}) == 0) {
			return;
		}
	}
	my $c		= substr($self->{buffer}, 0, 1, '');
	if ($c eq "\n") {
# 		$self->{linebuffer}	= '';
		$self->{line}	= 1+$self->{line};
		$self->{column}	= 1;
	} else {
# 		$self->{linebuffer}	.= $c;
		$self->{column}	= 1+$self->{column};
	}
	return $c;
}

sub _get_char {
	my $self	= shift;
	my $c		= substr($self->{buffer}, 0, 1, '');
	if ($c eq "\n") {
# 		$self->{linebuffer}	= '';
		$self->{line}	= 1+$self->{line};
		$self->{column}	= 1;
	} else {
# 		$self->{linebuffer}	.= $c;
		$self->{column}	= 1+$self->{column};
	}
	return $c;
}

sub _peek_char {
	my $self	= shift;
	if (length($self->{buffer}) == 0) {
		$self->fill_buffer;
		if (length($self->{buffer}) == 0) {
			return;
		}
	}
	my $c		= substr($self->{buffer}, 0, 1);
	return $c;
}

sub _read_word {
	my $self	= shift;
	my $word	= shift;
	while (length($self->{buffer}) < length($word)) {
		$self->fill_buffer;
	}
	
	if (substr($self->{buffer}, 0, length($word)) ne $word) {
		$self->_throw_error("Expected '$word'");
	}
	
	my $lines	= ($word =~ tr/\n//);
	my $lastnl	= rindex($word, "\n");
	my $cols	= length($word) - $lastnl - 1;
	$self->{lines}	+= $lines;
	if ($lines) {
		$self->{column}	= $cols;
	} else {
		$self->{column}	+= $cols;
	}
	substr($self->{buffer}, 0, length($word), '');
}

sub _read_length {
	my $self	= shift;
	my $len		= shift;
	while (length($self->{buffer}) < $len) {
		$self->fill_buffer;
	}
	
	my $word	= substr($self->{buffer}, 0, $len, '');
	my $lines	= ($word =~ tr/\n//);
	my $lastnl	= rindex($word, "\n");
	my $cols	= length($word) - $lastnl - 1;
	$self->{lines}	+= $lines;
	if ($lines) {
		$self->{column}	= $cols;
	} else {
		$self->{column}	+= $cols;
	}
	return $word;
}

sub _get_pname {
	my $self	= shift;
	my $prefix	= '';
	
	if ($self->{buffer} =~ /^$r_PNAME_LN/) {
		my $ln	= $self->_read_length($+[0]);
		my ($ns,$local)	= ($ln =~ /^([^:]*:)(.*)$/);
		no warnings 'uninitialized';
		$local	=~ s{\\([-~.!&'()*+,;=:/?#@%_\$])}{$1}g;
		return $self->new_token(PREFIXNAME, $ns, $local);
	} else {
		$self->{buffer} =~ $r_PNAME_NS;
		my $ns	= $self->_read_length($+[0]);
		return $self->new_token(PREFIXNAME, $ns);
	}
}

sub _get_iriref {
	my $self	= shift;
	$self->_get_char_safe(q[<]);
	my $iri	= '';
	while (1) {
		my $c	= $self->_peek_char;
		last unless defined($c);
		if (substr($self->{buffer}, 0, 1) eq '\\') {
			$self->_get_char_safe('\\');
			my $esc	= $self->_get_char;
			if ($esc eq '\\') {
				$iri	.= "\\";
			} elsif ($esc eq 'U') {
				my $codepoint	= $self->_read_length(8);
				unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
					$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
				}
				$iri .= chr(hex($codepoint));
			} elsif ($esc eq 'u') {
				my $codepoint	= $self->_read_length(4);
				unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
					$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
				}
				my $char	= chr(hex($codepoint));
				if ($char =~ /[<>" {}|\\^`]/) {
					$self->_throw_error(sprintf("Bad IRI character: '%s' (0x%x)", $char, ord($char)));
				}
				$iri .= $char;
			} else {
				$self->_throw_error("Unrecognized iri escape '$esc'");
			}
		} elsif ($self->{buffer} =~ /^[^<>\x00-\x20\\"{}|^`]+/) {
			$iri	.= $self->_read_length($+[0]);
		} elsif (substr($self->{buffer}, 0, 1) eq '>') {
			last;
		} else {
			$self->_throw_error("Got '$c' while expecting IRI character");
		}
	}
	$self->_get_char_safe(q[>]);
	return $self->new_token(IRI, $iri);
}

sub _get_bnode {
	my $self	= shift;
	$self->_read_word('_:');
	unless ($self->{buffer} =~ /^${r_bnode_id}/o) {
		$self->_throw_error("Expected: name");
	}
	my $name	= substr($self->{buffer}, 0, $+[0]);
	$self->_read_word($name);
	return $self->new_token(BNODE, $name);
}

sub _get_number {
	my $self	= shift;
	if ($self->{buffer} =~ /^${r_double}/) {
		return $self->new_token(DOUBLE, $self->_read_length($+[0]));
	} elsif ($self->{buffer} =~ /^${r_decimal}/) {
		return $self->new_token(DECIMAL, $self->_read_length($+[0]));
	} elsif ($self->{buffer} =~ /^${r_integer}/) {
		return $self->new_token(INTEGER, $self->_read_length($+[0]));
	} else {
		$self->_throw_error("Expected number");
	}
}

sub _get_comment {
	my $self	= shift;
	$self->_get_char_safe('#');
	my $comment	= '';
	my $c		= $self->_peek_char;
	while (length($c) and $c !~ /[\r\n]/) {
		$comment	.= $self->_get_char;
		$c			= $self->_peek_char;
	}
	if (length($c) and $c =~ /[\r\n]/) {
		$self->_get_char;
	}
	return $self->new_token(COMMENT, $comment);
}

sub _get_double_literal {
	my $self	= shift;
	my $c		= $self->_peek_char();
	$self->_get_char_safe(q["]);
	if (substr($self->{buffer}, 0, 2) eq q[""]) {
		# #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
		$self->_read_word(q[""]);
		
		my $quote_count	= 0;
		my $string	= '';
		while (1) {
			if (length($self->{buffer}) == 0) {
				$self->fill_buffer;
				if (length($self->{buffer}) == 0) {
					$self->_throw_error("Found EOF in string literal");
				}
			}
			if (substr($self->{buffer}, 0, 1) eq '"') {
				my $c	= $self->_get_char;
				$quote_count++;
				if ($quote_count == 3) {
					last;
				}
			} else {
				if ($quote_count) {
					$string	.= '"' foreach (1..$quote_count);
					$quote_count	= 0;
				}
				if (substr($self->{buffer}, 0, 1) eq '\\') {
					my $c	= $self->_get_char;
# 					$self->_get_char_safe('\\');
					my $esc	= $self->_get_char_fill_buffer;
					if ($esc eq '\\'){ $string .= "\\" }
					elsif ($esc eq '"'){ $string .= '"' }
					elsif ($esc eq "'"){ $string .= "'" }
					elsif ($esc eq 'r'){ $string .= "\r" }
					elsif ($esc eq 't'){ $string .= "\t" }
					elsif ($esc eq 'n'){ $string .= "\n" }
					elsif ($esc eq 'b'){ $string .= "\b" }
					elsif ($esc eq 'f'){ $string .= "\f" }
					elsif ($esc eq '>'){ $string .= ">" }
					elsif ($esc eq 'U'){
						my $codepoint	= $self->_read_length(8);
						unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
							$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
						}
						$string .= chr(hex($codepoint));
					}
					elsif ($esc eq 'u'){
						my $codepoint	= $self->_read_length(4);
						unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
							$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
						}
						$string .= chr(hex($codepoint));
					}
					else {
						$self->_throw_error("Unrecognized string escape '$esc'");
					}
				} else {
					$self->{buffer}	=~ /^[^"\\]+/;
					$string	.= $self->_read_length($+[0]);
				}
			}
		}
		return $self->new_token(STRING3D, $string);
	} else {
		### #x22 scharacter* #x22
		my $string	= '';
		while (1) {
			if (substr($self->{buffer}, 0, 1) eq '\\') {
				my $c	= $self->_peek_char;
				$self->_get_char_safe('\\');
				my $esc	= $self->_get_char;
				if ($esc eq '\\'){ $string .= "\\" }
				elsif ($esc eq '"'){ $string .= '"' }
				elsif ($esc eq "'"){ $string .= "'" }
				elsif ($esc eq 'r'){ $string .= "\r" }
				elsif ($esc eq 't'){ $string .= "\t" }
				elsif ($esc eq 'n'){ $string .= "\n" }
				elsif ($esc eq 'b'){ $string .= "\b" }
				elsif ($esc eq 'f'){ $string .= "\f" }
				elsif ($esc eq '>'){ $string .= ">" }
				elsif ($esc eq 'U'){
					my $codepoint	= $self->_read_length(8);
					unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
						$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
					}
					$string .= chr(hex($codepoint));
				}
				elsif ($esc eq 'u'){
					my $codepoint	= $self->_read_length(4);
					unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
						$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
					}
					$string .= chr(hex($codepoint));
				}
				else {
					$self->_throw_error("Unrecognized string escape '$esc'");
				}
			} elsif ($self->{buffer} =~ /^[^"\\]+/) {
				$string	.= $self->_read_length($+[0]);
			} elsif (substr($self->{buffer}, 0, 1) eq '"') {
				last;
			} else {
				$self->_throw_error("Got '$c' while expecting string character");
			}
		}
		$self->_get_char_safe(q["]);
		return $self->new_token(STRING1D, $string);
	}
}

sub _get_single_literal {
	my $self	= shift;
	my $c		= $self->_peek_char();
	$self->_get_char_safe("'");
	if (substr($self->{buffer}, 0, 2) eq q['']) {
		# #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
		$self->_read_word(q['']);
		
		my $quote_count	= 0;
		my $string	= '';
		while (1) {
			if (length($self->{buffer}) == 0) {
				$self->fill_buffer;
				if (length($self->{buffer}) == 0) {
					$self->_throw_error("Found EOF in string literal");
				}
			}
			if (substr($self->{buffer}, 0, 1) eq "'") {
				my $c	= $self->_get_char;
				$quote_count++;
				if ($quote_count == 3) {
					last;
				}
			} else {
				if ($quote_count) {
					$string	.= "'" foreach (1..$quote_count);
					$quote_count	= 0;
				}
				if (substr($self->{buffer}, 0, 1) eq '\\') {
					my $c	= $self->_get_char;
# 					$self->_get_char_safe('\\');
					my $esc	= $self->_get_char_fill_buffer;
					if ($esc eq '\\'){ $string .= "\\" }
					elsif ($esc eq '"'){ $string .= '"' }
					elsif ($esc eq "'"){ $string .= "'" }
					elsif ($esc eq 'r'){ $string .= "\r" }
					elsif ($esc eq 't'){ $string .= "\t" }
					elsif ($esc eq 'n'){ $string .= "\n" }
					elsif ($esc eq 'b'){ $string .= "\b" }
					elsif ($esc eq 'f'){ $string .= "\f" }
					elsif ($esc eq '>'){ $string .= ">" }
					elsif ($esc eq 'U'){
						my $codepoint	= $self->_read_length(8);
						unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
							$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
						}
						$string .= chr(hex($codepoint));
					}
					elsif ($esc eq 'u'){
						my $codepoint	= $self->_read_length(4);
						unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
							$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
						}
						$string .= chr(hex($codepoint));
					}
					else {
						$self->_throw_error("Unrecognized string escape '$esc'");
					}
				} else {
					$self->{buffer}	=~ /^[^'\\]+/;
					$string	.= $self->_read_length($+[0]);
				}
			}
		}
		return $self->new_token(STRING3S, $string);
	} else {
		### #x22 scharacter* #x22
		my $string	= '';
		while (1) {
			if (substr($self->{buffer}, 0, 1) eq '\\') {
				my $c	= $self->_peek_char;
				$self->_get_char_safe('\\');
				my $esc	= $self->_get_char;
				if ($esc eq '\\'){ $string .= "\\" }
				elsif ($esc eq '"'){ $string .= '"' }
				elsif ($esc eq "'"){ $string .= "'" }
				elsif ($esc eq 'r'){ $string .= "\r" }
				elsif ($esc eq 't'){ $string .= "\t" }
				elsif ($esc eq 'n'){ $string .= "\n" }
				elsif ($esc eq 'b'){ $string .= "\b" }
				elsif ($esc eq 'f'){ $string .= "\f" }
				elsif ($esc eq '>'){ $string .= ">" }
				elsif ($esc eq 'U'){
					my $codepoint	= $self->_read_length(8);
					unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
						$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
					}
					$string .= chr(hex($codepoint));
				}
				elsif ($esc eq 'u'){
					my $codepoint	= $self->_read_length(4);
					unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
						$self->_throw_error("Bad unicode escape codepoint '$codepoint'");
					}
					$string .= chr(hex($codepoint));
				}
				else {
					$self->_throw_error("Unrecognized string escape '$esc'");
				}
			} elsif ($self->{buffer} =~ /^[^'\\]+/) {
				$string	.= $self->_read_length($+[0]);
			} elsif (substr($self->{buffer}, 0, 1) eq "'") {
				last;
			} else {
				$self->_throw_error("Got '$c' while expecting string character");
			}
		}
		$self->_get_char_safe(q[']);
		return $self->new_token(STRING1S, $string);
	}
}

sub _get_keyword {
	my $self	= shift;
	$self->_get_char_safe('@');
	if ($self->{buffer} =~ /^base/) {
		$self->_read_word('base');
		return $self->new_token(BASE);
	} elsif ($self->{buffer} =~ /^prefix/) {
		$self->_read_word('prefix');
		return $self->new_token(PREFIX);
	} else {
		if ($self->{buffer} =~ /^[a-zA-Z]+(-[a-zA-Z0-9]+)*\b/) {
			my $lang	= $self->_read_length($+[0]);
			return $self->new_token(LANG, $lang);
		} else {
			$self->_throw_error("Expected keyword or language tag");
		}
	}
}

sub _throw_error {
	my $self	= shift;
	my $error	= shift;
	my $line	= $self->line;
	my $col		= $self->column;
# 	Carp::cluck "$line:$col: $error: " . Dumper($self->{buffer});
	RDF::Trine::Error::ParserError::Positioned->throw(
		-text => "$error at $line:$col",
		-value => [$line, $col],
	);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=end private

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
