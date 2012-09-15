package RDF::Trine::Parser::Turtle::Lexer;

use RDF::Trine::Parser::Turtle::Constants;
use 5.014;
use Moose;
use Data::Dumper;
use RDF::Trine::Error;

my $r_nameChar_extra		= qr'[-0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]'o;
my $r_nameStartChar_minus_underscore	= qr'[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]'o;
my $r_nameStartChar			= qr/[A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/;
my $r_nameChar				= qr/${r_nameStartChar}|[-0-9\x{b7}\x{0300}-\x{036f}\x{203F}-\x{2040}]/;
my $r_prefixName			= qr/(?:(?!_)${r_nameStartChar})(?:$r_nameChar)*/;
my $r_nameChar_test			= qr"(?:$r_nameStartChar|$r_nameChar_extra)";
my $r_double				= qr'[+-]?([0-9]+\.[0-9]*[eE][+-]?[0-9]+|\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)';
my $r_decimal				= qr'[+-]?([0-9]+\.[0-9]*|\.([0-9])+)';
my $r_integer				= qr'[+-]?[0-9]+';

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

sub lex_file {
	my $self	= shift;
	$self->get_token();
}

sub fill_buffer {
	my $self	= shift;
	unless (length($self->buffer)) {
		my $line	= $self->file->getline;
		if (defined($line)) {
			$self->{buffer}	.= $line;
		}
	}
}

sub check_for_bom {
	my $self	= shift;
	my $c	= $self->_peek_char();
	if ($c eq "\x{FEFF}") {
		$self->_get_char;
	}
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
# 	q[#]	=> 'get_comment',
	q[@]	=> 'get_keyword',
	q[<]	=> 'get_iriref',
	q[_]	=> 'get_bnode',
	q[']	=> 'get_literal',
	q["]	=> 'get_literal',
	q[:]	=> 'get_pname',
	(map {$_ => 'get_number'} (0 .. 9, '-', '+'))
);

sub get_token {
	my $self	= shift;
	while (1) {
		unless (length($self->{buffer})) {
			$self->fill_buffer;
		}
# 		warn "getting token with buffer: " . Dumper($self->{buffer});
		my $c	= $self->_peek_char();
		return unless (length($c));
		
		$self->start_column( $self->column );
		$self->start_line( $self->line );
		
		if (defined(my $name = $CHAR_TOKEN{$c})) { $self->_get_char; return $self->new_token($name); }
		elsif (defined(my $method = $METHOD_TOKEN{$c})) { return $self->$method() }
		elsif ($c eq '#') {
			# we're ignoring comment tokens, but we could return them here instead of falling through to the 'next':
			$self->get_comment();
			next;
		}
		elsif ($c =~ /[ \r\n\t]/) {
			while (length($c) and $c =~ /[\t\r\n ]/) {
				$self->_get_char;
				$c		= $self->_peek_char;
			}
			
			# we're ignoring whitespace tokens, but we could return them here instead of falling through to the 'next':
# 			return $self->new_token(WS);
			next;
		}
		elsif ($c =~ /[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/) {
			if ($self->{buffer} =~ /^a(?!:)\b/) {
				$self->_get_char;
				return $self->new_token(A);
			} elsif ($self->{buffer} =~ /^(?:true|false)\b/) {
				my $bool	= $self->_read_length($+[0]);
				return $self->new_token(BOOLEAN, $bool);
			} else {
				return $self->get_pname;
			}
		}
		elsif ($c eq '^') { $self->_read_word('^^'); return $self->new_token(HATHAT); }
		else {
# 			Carp::cluck sprintf("Unexpected byte '$c' (0x%02x)", ord($c));
			return $self->throw_error(sprintf("Unexpected byte '$c' (0x%02x)", ord($c)));
		}
		warn 'byte: ' . Dumper($c);
	}
}

sub _get_char_safe {
	my $self	= shift;
	my $char	= shift;
	my $c		= $self->_get_char;
	if ($c ne $char) {
		$self->throw_error("Expected '$char' but got '$c'");
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
		$self->throw_error("Expected '$word'");
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

sub get_pname {
	my $self	= shift;

	my $prefix	= '';
	if ($self->{buffer} =~ /^$r_nameStartChar_minus_underscore/) {
		my @parts;
		unless ($self->{buffer} =~ /^$r_nameStartChar_minus_underscore/o) {
			$self->throw_error("Expected: name");
		}
		my $nsc = substr($self->{buffer}, 0, $+[0]);
		$self->_read_word($nsc);
		push(@parts, $nsc);
		while ($self->{buffer} =~ /^$r_nameChar_test/) {
			my $nc;
			if ($self->{buffer} =~ /^$r_nameStartChar/) {
				$nc	= $self->_get_char();
			} else {
				unless ($self->{buffer} =~ /^$r_nameChar_extra/o) {
					$self->_error("Expected: nameStartChar");
				}
				$nc	= $self->_get_char();
			}
			push(@parts, $nc);
		}
		$prefix	= join('', @parts);
	}
	$self->_get_char_safe(':');
	if ($self->{buffer} =~ /^$r_nameStartChar/) {
		unless ($self->{buffer} =~ /^${r_nameStartChar}(?:${r_nameStartChar}|${r_nameChar_extra})*/o) {
			$self->_error("Expected: name");
		}
		my $name	= substr($self->{buffer}, 0, $+[0]);
		$self->_read_word($name);
		return $self->new_token(PREFIXNAME, $prefix, $name);
	} else {
		return $self->new_token(PREFIXNAME, $prefix);
	}
}

sub get_iriref {
	my $self	= shift;
	$self->_get_char_safe('<');
	$self->{buffer}	=~ qr'[^>\\]*(?:\\.[^>\\]*)*'o;
	my $iri = substr($self->{buffer}, 0, $+[0]);
	warn "iri: $iri";
	$self->_read_word($iri);
	$self->_get_char_safe('>');
	return $self->new_token(IRI, $iri);
}

sub get_bnode {
	my $self	= shift;
	$self->_read_word('_:');
	unless ($self->{buffer} =~ /^${r_nameStartChar}(?:${r_nameStartChar}|${r_nameChar_extra})*/o) {
		$self->_error("Expected: name");
	}
	my $name	= substr($self->{buffer}, 0, $+[0]);
	$self->_read_word($name);
	return $self->new_token(BNODE, $name);
}

sub get_number {
	my $self	= shift;
	if ($self->{buffer} =~ /^${r_double}/) {
		return $self->new_token(DOUBLE, $self->_read_length($+[0]));
	} elsif ($self->{buffer} =~ /^${r_decimal}/) {
		return $self->new_token(DECIMAL, $self->_read_length($+[0]));
	} elsif ($self->{buffer} =~ /^${r_integer}/) {
		return $self->new_token(INTEGER, $self->_read_length($+[0]));
	} else {
		$self->throw_error("Expected number");
	}
}

sub get_comment {
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

sub get_literal {
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
					$self->throw_error("Found EOF in string literal");
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
					given ($esc) {
						when('\\'){ $string .= "\\" }
						when('"'){ $string .= '"' }
						when('r'){ $string .= "\r" }
						when('t'){ $string .= "\t" }
						when('n'){ $string .= "\n" }
						when('U'){
							my $codepoint	= $self->_read_length(8);
							unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
								$self->throw_error("Bad unicode escape codepoint '$codepoint'");
							}
							$string .= chr(hex($codepoint));
						}
						when('u'){
							my $codepoint	= $self->_read_length(4);
							unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
								$self->throw_error("Bad unicode escape codepoint '$codepoint'");
							}
							$string .= chr(hex($codepoint));
						}
						default {
							$self->throw_error("Unrecognized string escape '$esc'");
						}
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
				given ($esc) {
					when('\\'){ $string .= "\\" }
					when('"'){ $string .= '"' }
					when('r'){ $string .= "\r" }
					when('t'){ $string .= "\t" }
					when('n'){ $string .= "\n" }
					when('U'){
						my $codepoint	= $self->_read_length(8);
						unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
							$self->throw_error("Bad unicode escape codepoint '$codepoint'");
						}
						$string .= chr(hex($codepoint));
					}
					when('u'){
						my $codepoint	= $self->_read_length(4);
						unless ($codepoint =~ /^[0-9A-Fa-f]+$/) {
							$self->throw_error("Bad unicode escape codepoint '$codepoint'");
						}
						$string .= chr(hex($codepoint));
					}
					default {
						$self->throw_error("Unrecognized string escape '$esc'");
					}
				}
			} elsif ($self->{buffer} =~ /^[^"\\]+/) {
				$string	.= $self->_read_length($+[0]);
			} elsif (substr($self->{buffer}, 0, 1) eq '"') {
				last;
			} else {
				$self->throw_error("Got '$c' while expecting string character");
			}
		}
		$self->_get_char_safe(q["]);
		return $self->new_token(STRING1D, $string);
	}
}

sub get_keyword {
	my $self	= shift;
	$self->_get_char_safe('@');
	if ($self->{buffer} =~ /^base/) {
		$self->_read_word('base');
		return $self->new_token(BASE);
	} elsif ($self->{buffer} =~ /^prefix/) {
		$self->_read_word('prefix');
		return $self->new_token(PREFIX);
	} else {
		if ($self->{buffer} =~ /^[a-z]+(-[a-z0-9]+)*\b/) {
			my $lang	= $self->_read_length($+[0]);
			return $self->new_token(LANG, $lang);
		} else {
			$self->throw_error("Expected keyword or language tag");
		}
	}
}

sub throw_error {
	my $self	= shift;
	my $error	= shift;
	my $line	= $self->start_line;
	my $col		= $self->start_column;
# 	Carp::cluck "$line:$col: $error: " . Dumper($self->{buffer});
	RDF::Trine::Error::ParserError::Positioned->throw(
		-text => "$error at $line:$col",
		-value => [$line, $col],
	);
}

__PACKAGE__->meta->make_immutable;

