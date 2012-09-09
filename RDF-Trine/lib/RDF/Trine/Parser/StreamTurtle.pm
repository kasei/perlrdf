package RDF::Trine::Parser::StreamTurtle;

use utf8;
use 5.014;
use Scalar::Util qw(blessed);
use base qw(RDF::Trine::Parser);
use RDF::Trine::Error qw(:try);
use Data::Dumper;

my $rdf	= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $xsd	= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');

sub new {
	my $class	= shift;
	my %args	= @_;
	return bless({ %args, stack => [] }, $class);
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	local($self->{baseURI})	= shift;
	my $string				= shift;
	local($self->{handle_triple}) = shift;
	open(my $fh, '<:encoding(UTF-8)', \$string);
	my $l	= RDF::Trine::Parser::TurtleLexer->new($fh);
	$self->_parse($l);
}

=item C<< parse_file ( $base_uri, $fh, $handler ) >>

Parses all data read from the filehandle or file C<< $fh >>, using the given
C<< $base_uri >>. If C<< $fh >> is a filename, this method can guess the
associated parse. For each RDF statement parses C<< $handler >> is called.

=cut

sub parse_file {
	my $self	= shift;
	local($self->{baseURI})	= shift;
	my $fh		= shift;
	local($self->{handle_triple}) = shift;

	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		unless ($self->can('parse')) {
			my $pclass = $self->guess_parser_by_filename( $filename );
			$self = $pclass->new() if ($pclass and $pclass->can('new'));
		}
		open( $fh, '<:encoding(UTF-8)', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	my $l	= RDF::Trine::Parser::TurtleLexer->new($fh);
	$self->_parse($l);
}

sub _parse {
	my $self	= shift;
	my $l		= shift;
	$l->check_for_bom;
	$self->{map}	= RDF::Trine::NamespaceMap->new();
	while (my $t = $self->_next_nonws($l)) {
		$self->_statement($l, $t);
	}
}

################################################################################

sub _unget_token {
	my $self	= shift;
	my $t		= shift;
	push(@{ $self->{ stack } }, $t);
}

sub _next_nonws {
	my $self	= shift;
	my $l		= shift;
	if (scalar(@{ $self->{ stack } })) {
		return pop(@{ $self->{ stack } });
	}
	while (1) {
		my $t	= $l->get_token;
		return unless ($t);
		next if ($t->type eq 'WS' or $t->type eq 'COMMENT');
		return $t;
	}
}

sub _get_token_type {
	my $self	= shift;
	my $l		= shift;
	my $type	= shift;
	my $t		= $self->_next_nonws($l);
	return unless ($t);
	unless ($t->type eq $type) {
		$self->throw_error("Expecting $type but got " . $t->type, $t, $l);
	}
	return $t;
}

sub _statement {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $type	= $t->type;
	given ($type) {
		when ('WS') {}
		when ('PREFIX') {
			$t	= $self->_get_token_type($l, 'PREFIXNAME');
			my $name	= $t->value;
			$t	= $self->_get_token_type($l, 'IRI');
			my $iri	= $t->value;
			$t	= $self->_get_token_type($l, 'DOT');
			$self->{map}->add_mapping( $name => $iri );
		}
		when ('BASE') {
			$t	= $self->_get_token_type($l, 'IRI');
			my $iri	= $t->value;
			$t	= $self->_get_token_type($l, 'DOT');
			$self->{baseURI}	= $iri;
		}
		default {
			# subject
			my $subj;
			if ($t->type eq 'LBRACKET') {
				$subj	= RDF::Trine::Node::Blank->new();
				my $t	= $self->_next_nonws($l);
				if ($t->type ne 'RBRACKET') {
					$self->_unget_token($t);
					$self->_predicateObjectList( $l, $subj );
					$t	= $self->_get_token_type($l, 'RBRACKET');
				}
			} elsif ($t->type eq 'LPAREN') {
				my $t	= $self->_next_nonws($l);
				if ($t->type eq 'RPAREN') {
					$subj	= RDF::Trine::Node::Resource->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
				} else {
					$subj	= RDF::Trine::Node::Blank->new();
					my @objects	= $self->_object($l, $t);
					
					while (1) {
						my $t	= $self->_next_nonws($l);
						if ($t->type eq 'RPAREN') {
							last;
						} else {
							push(@objects, $self->_object($l, $t));
						}
					}
					$self->_assert_list($subj, @objects);
				}
			} elsif (not($t->type eq 'IRI' or $t->type eq 'PREFIXNAME' or $t->type eq 'BNODE')) {
				$self->throw_error("Expecting resource or bnode but got " . $t->type, $t, $l);
			} else {
				$subj	= $self->_token_to_node($t);
			}
# 			warn "Subject: $subj\n";
			
			#predicateObjectList
			$self->_predicateObjectList($l, $subj);

			$t	= $self->_get_token_type($l, 'DOT');
		}
	}
}

sub _assert_list {
	my $self	= shift;
	my $subj	= shift;
	my @objects	= @_;
	my $head	= $subj;
	while (@objects) {
		my $obj	= shift(@objects);
		$self->_triple($head, $rdf->first, $obj);
		my $next	= scalar(@objects) ? RDF::Trine::Node::Blank->new() : $rdf->nil;
		$self->_triple($head, $rdf->next, $next);
		$head		= $next;
	}
}

sub _predicateObjectList {
	my $self	= shift;
	my $l		= shift;
	my $subj	= shift;
	my $t		= $self->_next_nonws($l);
	while (1) {
		unless ($t->type eq 'IRI' or $t->type eq 'PREFIXNAME' or $t->type eq 'A') {
			$self->throw_error("Expecting verb but got " . $t->type, $t, $l);
		}
		my $pred	= $self->_token_to_node($t);
# 		warn "Predicate: $pred\n";
		$self->_objectList($l, $subj, $pred);
		
		my $t		= $self->_next_nonws($l);
		last unless ($t);
		if ($t->type eq 'SEMICOLON') {
			my $t		= $self->_next_nonws($l);
			if ($t->type eq 'IRI' or $t->type eq 'PREFIXNAME' or $t->type eq 'A') {
				next;
			} else {
				$self->_unget_token($t);
				return;
			}
		} else {
			$self->_unget_token($t);
			return;
		}
	}
}

sub _objectList {
	my $self	= shift;
	my $l		= shift;
	my $subj	= shift;
	my $pred	= shift;
	while (1) {
		my $t		= $self->_next_nonws($l);
		last unless ($t);
		my $obj		= $self->_object($l, $t);
		$self->_triple($subj, $pred, $obj);
		
		my $t		= $self->_next_nonws($l);
		if ($t->type eq 'COMMA') {
			next;
		} else {
			$self->_unget_token($t);
			return;
		}
	}
}

sub _triple {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	if ($self->{canonicalize} and blessed($obj) and $obj->isa('RDF::Trine::Node::Literal')) {
		$obj	= $obj->canonicalize;
	}
	
	my $t		= RDF::Trine::Statement->new($subj, $pred, $obj);
# 	warn $t->as_string;
	if ($self->{handle_triple}) {
		$self->{handle_triple}->( $t );
	}
}


sub _object {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $obj;
	my $type	= $t->type;
	if ($type eq 'LBRACKET') {
		$obj	= RDF::Trine::Node::Blank->new();
		my $t	= $self->_next_nonws($l);
		if ($t->type ne 'RBRACKET') {
			$self->_unget_token($t);
			$self->_predicateObjectList( $l, $obj );
			$t	= $self->_get_token_type($l, 'RBRACKET');
		}
	} elsif ($type eq 'LPAREN') {
		my $t	= $self->_next_nonws($l);
		if ($t->type eq 'RPAREN') {
			$obj	= RDF::Trine::Node::Resource->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
		} else {
			$obj	= RDF::Trine::Node::Blank->new();
			my @objects	= $self->_object($l, $t);
			
			while (1) {
				my $t	= $self->_next_nonws($l);
				if ($t->type eq 'RPAREN') {
					last;
				} else {
					push(@objects, $self->_object($l, $t));
				}
			}
			$self->_assert_list($obj, @objects);
		}
	} elsif (not($type eq 'IRI' or $type eq 'PREFIXNAME' or $type eq 'A' or $type eq '1DSTRING' or $type eq '3DSTRING' or $type eq 'BNODE' or $type eq 'INTEGER' or $type eq 'DECIMAL' or $type eq 'DOUBLE' or $type eq 'BOOLEAN')) {
		$self->throw_error("Expecting object but got " . $type, $t, $l);
	} else {
		if ($type eq '1DSTRING' or $type eq '3DSTRING') {
			my $value	= $t->value;
			my $t		= $self->_next_nonws($l);
			my $dt;
			my $lang;
			if ($t->type eq 'HATHAT') {
				my $t		= $self->_next_nonws($l);
				if ($t->type eq 'IRI' or $t->type eq 'PREFIXNAME') {
					$dt	= $self->_token_to_node($t);
				}
			} elsif ($t->type eq 'LANG') {
				$lang	= $t->value;
			} else {
				$self->_unget_token($t);
			}
			$obj	= RDF::Trine::Node::Literal->new($value, $lang, $dt);
		} else {
			$obj	= $self->_token_to_node($t);
		}
	}
	return $obj;
}

sub _token_to_node {
	my $self	= shift;
	my $t		= shift;
	my $type	= $t->type;
	given ($type) {
		when ('A') {
			return $rdf->type;
		}
		when ('IRI') {
			return RDF::Trine::Node::Resource->new($t->value);
		}
		when ('INTEGER') {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->integer);
		}
		when ('DECIMAL') {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->decimal);
		}
		when ('DOUBLE') {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->double);
		}
		when ('BOOLEAN') {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->boolean);
		}
		when ('PREFIXNAME') {
			my ($ns, $local)	= @{ $t->args };
			my $prefix	= $self->{map}->namespace_uri($ns);
			my $iri		= $prefix->uri($local);
			return $iri;
		}
		when ('BNODE') {
			return RDF::Trine::Node::Blank->new($t->value);
		}
		default {
			$self->throw_error("Converting $type to node not implemented", $t);
		}
	}
}

sub throw_error {
	my $self	= shift;
	my $message	= shift;
	my $t		= shift;
	my $l		= shift;
	my $line	= $t->line;
	my $col		= $t->column;
# 	Carp::cluck "$message at $line:$col";
	throw RDF::Trine::Error::ParserError -text => "$message at $line:$col ('" . $t->value . "')";
}

package RDF::Trine::Parser::TurtleLexer;

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

sub BUILDARGS {
	my $class	= shift;
	if (scalar(@_) == 1) {
		return { file => shift };
	} else {
		return $class->SUPER::BUILDARGS(@_);
	}
}

sub new_token {
	my $self	= shift;
	my $type	= shift;
	my $line	= $self->line;
	my $col		= $self->column;
	return RDF::Trine::Parser::TurtleToken->new( type => $type, line => $line, column => $col, args => \@_ );
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

sub get_token {
	my $self	= shift;
	$self->fill_buffer;
# 	warn "getting token with buffer: " . Dumper($self->{buffer});
	my $c	= $self->_peek_char();
	return unless (length($c));
	given ($c) {
		when('#') { return $self->get_comment }
		when('@') { return $self->get_keyword }
		when(/[ \r\n]/) { return $self->get_whitespace }
		when('[') { $self->_get_char; return $self->new_token('LBRACKET'); }
		when(']') { $self->_get_char; return $self->new_token('RBRACKET'); }
		when('(') { $self->_get_char; return $self->new_token('LPAREN'); }
		when(')') { $self->_get_char; return $self->new_token('RPAREN'); }
		when('<') { return $self->get_iriref }
		when('_') { return $self->get_bnode }
		when(/[-+0-9]/) { return $self->get_number }
		when(q[']) { return $self->get_literal }
		when(q["]) { return $self->get_literal }
		when(':') { return $self->get_pname }
		when('.') { $self->_get_char; return $self->new_token('DOT'); }
		when(';') { $self->_get_char; return $self->new_token('SEMICOLON'); }
		when(',') { $self->_get_char; return $self->new_token('COMMA'); }
		when('^') { $self->_read_word('^^'); return $self->new_token('HATHAT'); }
		when(/[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/) {
			if ($self->{buffer} =~ /^a(?!:)\b/) {
				$self->_get_char;
				return $self->new_token('A');
			} elsif ($self->{buffer} =~ /^(?:true|false)\b/) {
				my $bool	= $self->_read_length($+[0]);
				return $self->new_token('BOOLEAN', $bool);
			} else {
				return $self->get_pname;
			}
		}
		default {
			return $self->throw_error("Unexpected byte '$c'");
		}
	}
	warn 'byte: ' . Dumper($c);
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
		$self->{cols}	= $cols;
	} else {
		$self->{cols}	+= $cols;
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
		$self->{cols}	= $cols;
	} else {
		$self->{cols}	+= $cols;
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
		unless ($self->{buffer} =~ /^${r_nameStartChar}(${r_nameStartChar}|${r_nameChar_extra})*/o) {
			$self->_error("Expected: name");
		}
		my $name	= substr($self->{buffer}, 0, $+[0]);
		$self->_read_word($name);
		return $self->new_token('PREFIXNAME', $prefix, $name);
	} else {
		return $self->new_token('PREFIXNAME', $prefix);
	}
}

sub get_iriref {
	my $self	= shift;
	$self->_get_char_safe('<');
	$self->{buffer}	=~ qr'[^>\\]*(?:\\.[^>\\]*)*'o;
	my $iri = substr($self->{buffer}, 0, $+[0]);
	$self->_read_word($iri);
	$self->_get_char_safe('>');
	return $self->new_token('IRI', $iri);
}

sub get_bnode {
	my $self	= shift;
	$self->_read_word('_:');
	unless ($self->{buffer} =~ /^${r_nameStartChar}(${r_nameStartChar}|${r_nameChar_extra})*/o) {
		$self->_error("Expected: name");
	}
	my $name	= substr($self->{buffer}, 0, $+[0]);
	$self->_read_word($name);
	return $self->new_token('BNODE', $name);
}

sub get_number {
	my $self	= shift;
	if ($self->{buffer} =~ /^${r_double}/) {
		return $self->new_token('DOUBLE', $self->_read_length($+[0]));
	} elsif ($self->{buffer} =~ /^${r_decimal}/) {
		return $self->new_token('DECIMAL', $self->_read_length($+[0]));
	} elsif ($self->{buffer} =~ /^${r_integer}/) {
		return $self->new_token('INTEGER', $self->_read_length($+[0]));
	} else {
		$self->throw_error("Expected number");
	}
}

sub get_whitespace {
	my $self	= shift;
	my $c		= $self->_peek_char;
	while (length($c) and $c =~ /[\r\n ]/) {
		$self->_get_char;
		$c		= $self->_peek_char;
	}
	return $self->new_token('WS');
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
	return $self->new_token('COMMENT', $comment);
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
		return $self->new_token('3DSTRING', $string);
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
		return $self->new_token('1DSTRING', $string);
	}
}

sub get_keyword {
	my $self	= shift;
	$self->_get_char_safe('@');
	if ($self->{buffer} =~ /^base/) {
		$self->_read_word('base');
		return $self->new_token('BASE');
	} elsif ($self->{buffer} =~ /^prefix/) {
		$self->_read_word('prefix');
		return $self->new_token('PREFIX');
	} else {
		if ($self->{buffer} =~ /^[a-z]+(-[a-z0-9]+)*/) {
			my $lang	= $self->_read_length($+[0]);
			return $self->new_token('LANG', $lang);
		} else {
			$self->throw_error("Expected keyword or language tag");
		}
	}
}

sub throw_error {
	my $self	= shift;
	my $error	= shift;
	my $line	= $self->line;
	my $col		= $self->column;
# 	Carp::cluck "$line:$col: $error: " . Dumper($self->{buffer});
	throw RDF::Trine::Error::ParserError -text => "$line:$col: $error";
}

__PACKAGE__->meta->make_immutable;

package RDF::Trine::Parser::TurtleToken;

use 5.014;
use Moose;

has type => ( is => 'ro', isa => 'Str', required => 1 );
has line => ( is => 'ro', isa => 'Int', required => 1 );
has column => ( is => 'ro', isa => 'Int', required => 1 );
has args => ( is => 'ro', required => 1 );

sub value {
	my $self	= shift;
	my $args	= $self->args;
	return $args->[0];
}

__PACKAGE__->meta->make_immutable;

1;
