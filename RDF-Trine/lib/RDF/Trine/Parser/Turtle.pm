# RDF::Trine::Parser::Turtle
# -------------
# $Revision: 127 $
# $Date: 2006-02-08 14:53:21 -0500 (Wed, 08 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::Turtle - Turtle RDF Parser.

=head1 VERSION

This document describes RDF::Trine::Parser::Turtle version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 my $iterator = $parser->parse( $base_uri, $data );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::Turtle;

use strict;
use warnings;
no warnings 'redefine';
our $VERSION	= '1.000';

BEGIN {
	foreach my $t ('turtle', 'application/x-turtle', 'application/turtle') {
		$RDF::Trine::Parser::types{ $t }	= __PACKAGE__;
	}
}


use URI;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Parser::Error;
use Scalar::Util qw(blessed looks_like_number);

our $r_boolean				= qr'(?:true|false)';
our $r_comment				= qr'#[^\r\n]*';
our $r_decimal				= qr'[+-]?([0-9]+\.[0-9]*|\.([0-9])+)';
our $r_double				= qr'[+-]?([0-9]+\.[0-9]*[eE][+-]?[0-9]+|\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)';
our $r_integer				= qr'[+-]?[0-9]+';
our $r_language				= qr'[a-z]+(-[a-z0-9]+)*';
our $r_lcharacters			= qr'(?s)[^"\\]*(?:(?:\\.|"(?!""))[^"\\]*)*';
our $r_line					= qr'([^\r\n]+[\r\n]+)(?=[^\r\n])';
our $r_nameChar_extra		= qr'[-0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]';
our $r_nameStartChar		= qr'[A-Z_a-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]';
our $r_nameStartChar_minus_underscore	= qr'[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]';
our $r_scharacters			= qr'[^"\\]*(?:\\.[^"\\]*)*';
our $r_ucharacters			= qr'[^>\\]*(?:\\.[^>\\]*)*';
our $r_booltest				= qr'(true|false)\b';
our $r_resource_test		= qr/(?![_[("0-9+-]|$r_booltest)/;
our $r_nameChar_test		= qr"(?:$r_nameStartChar|$r_nameChar_extra)";

my $debug		= 0;
my $rdf			= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $xsd			= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');


=item C<< new >>

Returns a new Turtle parser.

=cut

sub new {
	my $class	= shift;
	my $self	= bless({
					bindings	=> {},
					bnode_id	=> 0,
				}, $class);
	return $self;
}

=item C<< parse ( $base_uri, $data ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	local($self->{baseURI})	= $uri;
	local($self->{tokens})	= $input;
	return $self->_turtleDoc();
}

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF triple
parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

sub parse_into_model {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	my $model	= shift;
	local($self->{handle_triple})	= sub {
		my $st	= shift;
		$model->add_statement( $st );
	};
	return $self->parse( $uri, $input );
}

sub _eat_re {
	my $self	= shift;
	my $thing	= shift;
	if (not(length($self->{tokens}))) {
		Carp::cluck("no tokens left ($thing)") if ($debug);
		throw RDF::Trine::Parser::Error::ValueError -text => "No tokens";
	}
	
	if ($self->{tokens} =~ /^$thing/) {
		my $match	= $&;
		substr($self->{tokens}, 0, length($match))	= '';
		return $match;
	}
	Carp::cluck("Expected ($thing)") if ($debug);
	throw RDF::Trine::Parser::Error::ValueError -text => "Expected: $thing";
}

sub _eat {
	my $self	= shift;
	my $thing	= shift;
	if (not(length($self->{tokens}))) {
		Carp::cluck("no tokens left ($thing)") if ($debug);
		throw RDF::Trine::Parser::Error::ValueError -text => "No tokens";
	}
	
# 	if (substr($self->{tokens}, 0, 1) eq '^') {
# 		Carp::cluck( "eating $thing with input $self->{tokens}" );
# 	}
	
# 	if (blessed($thing) and $thing->isa('Regexp')) {
# 		$self->_eat_re( $thing );
# 	} elsif ($thing =~ /^\d+/) {
# 		my ($token)	= substr( $self->{tokens}, 0, $thing, '' );
# 		return $token
# 	} else {
		### thing is a string
		if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
			substr($self->{tokens}, 0, length($thing))	= '';
			return $thing;
		} else {
			Carp::cluck("expected: $thing, got: $self->{tokens}") if ($debug);
			throw RDF::Trine::Parser::Error::ValueError -text => "Expected: $thing";
		}
# 	}
# 	print $thing;
# 	throw Error;
}

sub _test {
	my $self	= shift;
	my $thing	= shift;
	if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
		return 1;
	} else {
		return 0;
	}
}

sub _triple {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	foreach my $n ($s, $p, $o) {
		unless (blessed($n) and $n->isa('RDF::Trine::Node')) {
			throw RDF::Trine::Parser::Error;
		}
	}
	
	if (my $code = $self->{handle_triple}) {
		my $st	= RDF::Trine::Statement->new( $s, $p, $o );
		$code->( $st );
	}
	
	my $count	= ++$self->{triple_count};
	warn "$count\n" if ($debug);
#	print join(' ', map { $_->sse } ($s, $p, $o)), '.' . "\n";
}

sub _turtleDoc {
	my $self	= shift;
	while ($self->_statement_test()) {
		$self->_statement();
	}
}

sub _statement_test {
	my $self	= shift;
	if (length($self->{tokens})) {
		return 1;
	} else {
		return 0;
	}
}

sub _statement {
	my $self	= shift;
	if ($self->_directive_test()) {
		$self->_directive();
		$self->__consume_ws();
		$self->_eat('.');
		$self->__consume_ws();
	} elsif ($self->_triples_test()) {
		$self->_triples();
		$self->__consume_ws();
		$self->_eat('.');
		$self->__consume_ws();
	}  else {
		$self->_ws();
		$self->__consume_ws();
	}
}

sub _directive_test {
	my $self	= shift;
	### between directive | triples | ws
	### directives must start with @, triples must not
	if ($self->__startswith('@')) {
		return 1;
	} else {
		return 0;
	}
}

sub _directive {
	my $self	= shift;
	### prefixID | base
	if ($self->_prefixID_test()) {
		$self->_prefixID();
	} else {
		$self->_base();
	}
}

sub _prefixID_test {
	my $self	= shift;
	### between prefixID | base. prefixID is @prefix, base is @base
	if ($self->__startswith('@prefix')) {
		return 1;
	} else {
		return 0;
	}
}

sub _prefixID {
	my $self	= shift;
	### '@prefix' ws+ prefixName? ':' ws+ uriref
	$self->_eat('@prefix');
	$self->_ws();
	$self->__consume_ws();
	
	my $prefix;
	if ($self->_prefixName_test()) {
		$prefix = $self->_prefixName();
	} else {
		$prefix	= '';
	}
	
	$self->_eat(':');
	$self->_ws();
	$self->__consume_ws();
	
	my $uri = $self->_uriref();
	$self->{bindings}{$prefix}	= $uri;
}



sub _base {
	my $self	= shift;
	### '@base' ws+ uriref
	$self->_eat('@base');
	$self->_ws();
	$self->__consume_ws();
	$self->{baseURI}	=	$self->_join_uri($self->{baseURI}, $self->_uriref()->uri_value);
}

sub _triples_test {
	my $self	= shift;
	### between triples and ws. disjoint, so easy enough
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ /^[\r\n\t #]/) {
		return 1;
	} else {
		return 0;
	}
}

sub _triples {
	my $self	= shift;
	### subject ws+ predicateObjectList
	my $subj	= $self->_subject();
	$self->_ws();
	$self->__consume_ws;
	foreach my $data ($self->_predicateObjectList()) {
		my ($pred, $objt)	= @$data;
		$self->_triple( $subj, $pred, $objt );
	}
}

sub _predicateObjectList {
	my $self	= shift;
	### verb ws+ objectList ( ws* ';' ws* verb ws+ objectList )* (ws* ';')?
	my $pred = $self->_verb();
	$self->_ws();
	$self->__consume_ws();
	
	my @list;
	foreach my $objt ($self->_objectList()) {
		push(@list, [$pred, $objt]);
	}
	
	while ($self->{tokens} =~ m/^[\t\r\n #]*;/) {
		$self->__consume_ws();
		$self->_eat(';');
		$self->__consume_ws();
		if ($self->_verb_test()) { # @@
			$pred = $self->_verb();
			$self->_ws();
			$self->__consume_ws();
			foreach my $objt ($self->_objectList()) {
				push(@list, [$pred, $objt]);
			}
		} else {
			last
		}
	}
	
	return @list;
}

sub _objectList {
	my $self	= shift;
	### object (ws* ',' ws* object)*
	my @list;
	push(@list, $self->_object());
	$self->__consume_ws();
	while ($self->_test(',')) {
		$self->__consume_ws();
		$self->_eat(',');
		$self->__consume_ws();
		push(@list, $self->_object());
		$self->__consume_ws();
	}
	return @list;
}

sub _verb_test {
	my $self	= shift;
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ /^[.]/) {
		return 1;
	} else {
		return 0;
	}
}

sub _verb {
	my $self	= shift;
	### predicate | a
	if ($self->_predicate_test()) {
		return $self->_predicate();
	} else {
		$self->_eat('a');
		return $rdf->type;
	}
}

sub _comment {
	my $self	= shift;
	### '#' ( [^#xA#xD] )*
	$self->_eat_re($r_comment);
}

sub _subject {
	my $self	= shift;
	### resource | blank
#	if ($self->_resource_test()) {
	if (length($self->{tokens}) and $self->{tokens} =~ /^$r_resource_test/) {
		return $self->_resource();
	} else {
		return $self->_blank();
	}
}

sub _predicate_test {
	my $self	= shift;
	### between this and 'a'... a little tricky
	### if it's a, it'll be followed by whitespace; whitespace is mandatory
	### after a verb, which is the only thing predicate appears in
	return 0 unless (length($self->{tokens}));
	if (not $self->__startswith('a')) {
		return 1
	} elsif ($self->{tokens} !~ m/^a[\r\n\t #]/) {
		return 1
	} else {
		return 0
	}
}

sub _predicate {
	my $self	= shift;
	### resource
	return $self->_resource();
}

sub _object {
	my $self	= shift;
	### resource | blank | literal
#	if ($self->_resource_test()) {
	if (length($self->{tokens}) and $self->{tokens} =~ /^$r_resource_test/) {
		return $self->_resource();
	} elsif ($self->_blank_test()) {
		return $self->_blank();
	} else {
		return $self->_literal();
	}
}

sub _literal {
	my $self	= shift;
	### quotedString ( '@' language )? | datatypeString | integer | 
	### double | decimal | boolean
	### datatypeString = quotedString '^^' resource      
	### (so we change this around a bit to make it parsable without a huge 
	### multiple lookahead)
	
	if ($self->_quotedString_test()) {
		my $value = $self->_quotedString();
		if ($self->_test('@')) {
			$self->_eat('@');
			my $lang = $self->_language();
			return $self->__Literal($value, $lang);
		} elsif ($self->_test('^^')) {
			$self->_eat('^^');
			my $dtype = $self->_resource();
			return $self->_typed($value, $dtype);
		} else {
			return $self->__Literal($value);
		}
	} elsif ($self->_double_test()) {
		return $self->_double();
	} elsif ($self->_decimal_test()) {
		return $self->_decimal();
	} elsif ($self->_integer_test()) {
		return $self->_integer();
	} else {
		return $self->_boolean();
	}
}

sub _double_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_double/) {
		return 1;
	} else {
		return 0;
	}
}

sub _double {
	my $self	= shift;
	### ('-' | '+') ? ( [0-9]+ '.' [0-9]* exponent | '.' ([0-9])+ exponent 
	### | ([0-9])+ exponent )
	### exponent = [eE] ('-' | '+')? [0-9]+
	my $token	= $self->_eat_re( $r_double );
	return $self->_typed( $token, $xsd->double );
}

sub _decimal_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_decimal/) {
		return 1;
	} else {
		return 0;
	}
}

sub _decimal {
	my $self	= shift;
	### ('-' | '+')? ( [0-9]+ '.' [0-9]* | '.' ([0-9])+ | ([0-9])+ )
	my $token	= $self->_eat_re( $r_decimal );
	return $self->_typed( $token, $xsd->decimal );
}

sub _integer_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_integer/) {
		return 1;
	} else {
		return 0;
	}
}

sub _integer {
	my $self	= shift;
	### ('-' | '+')? ( [0-9]+ '.' [0-9]* | '.' ([0-9])+ | ([0-9])+ )
	my $token	= $self->_eat_re( $r_integer );
	return $self->_typed( $token, $xsd->integer );
}

sub _boolean {
	my $self	= shift;
	### 'true' | 'false'
	my $token	= $self->_eat_re( $r_boolean );
	return $self->_typed( $token, $xsd->boolean );
}

sub _blank_test {
	my $self	= shift;
	### between this and literal. urgh!
	### this can start with...
	### _ | [ | (
	### literal can start with...
	### * " | + | - | digit | t | f
	if ($self->{tokens} =~ m/^[_[(]/) {
		return 1;
	} else {
		return 0;
	}
}

sub _blank {
	my $self	= shift;
	### nodeID | '[]' | '[' ws* predicateObjectList ws* ']' | collection
	if ($self->_nodeID_test) {
		return $self->__bNode($self->_nodeID());
	} elsif ($self->_test('[]')) {
		$self->_eat('[]');
		return $self->__bNode( $self->__generate_bnode_id() );
	} elsif ($self->_test('[')) {
		$self->_eat('[');
		my $subj	= $self->__bNode( $self->__generate_bnode_id() );
		$self->__consume_ws();
		foreach my $data ($self->_predicateObjectList()) {
			my ($pred, $objt)	= @$data;
			$self->_triple( $subj, $pred, $objt );
		}
		$self->__consume_ws();
		$self->_eat(']');
		return $subj;
	} else {
		return $self->_collection();
	}
}

sub _itemList_test {
	my $self	= shift;
	### between this and whitespace or ')'
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ m/^[\r\n\t #)]/) {
		return 1;
	} else {
		return 0;
	}
}

sub _itemList {
	my $self	= shift;
	### object (ws+ object)*
	my @list;
	push(@list, $self->_object());
	while ($self->_ws_test()) {
		$self->__consume_ws();
		if (not $self->_test(')')) {
			push(@list, $self->_object());
		}
	}
	return @list;
}

sub _collection {
	my $self	= shift;
	### '(' ws* itemList? ws* ')'
	my $b	= $self->__bNode( $self->__generate_bnode_id() );
	my ($this, $rest)	= ($b, undef);
	$self->_eat('(');
	$self->__consume_ws();
	if ($self->_itemList_test()) {
#		while (my $objt = $self->_itemList()) {
		foreach my $objt ($self->_itemList()) {
			if (defined($rest)) {
				$this	= $self->__bNode( $self->__generate_bnode_id() );
				$self->_triple( $rest, $rdf->rest, $this)
			}
			$self->_triple( $this, $rdf->first, $objt );
			$rest = $this;
		}
	}
	if (defined($rest)) {
		$self->_triple( $rest, $rdf->rest, $rdf->nil );
	} else {
		$b = $rdf->nil;
	}
	$self->__consume_ws();
	$self->_eat(')');
	return $b;
}

sub _ws_test {
	my $self	= shift;
	unless (length($self->{tokens})) {
		return 0;
	}
	
	if ($self->{tokens} =~ m/^[\t\r\n #]/) {
		return 1;
	} else {
		return 0;
	}
}

sub _ws {
	my $self	= shift;
	### #x9 | #xA | #xD | #x20 | comment
	if ($self->_test('#')) {
		$self->_comment();
	} else {
		my $ws	= $self->_eat_re( qr/[\n\r\t ]+/ );
		unless ($ws =~ /^[\n\r\t ]/) {
			throw RDF::Trine::Parser::Error::ValueError -text => 'Not whitespace';
		}
	}
}

sub _resource_test {
	my $self	= shift;
	### between this and blank and literal
	### quotedString ( '@' language )? | datatypeString | integer |
	### double | decimal | boolean
	### datatypeString = quotedString '^^' resource
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ m/^([_["0-9+-]|$r_booltest)/) {# and $self->{tokens} !~ $r_booltest) {
		return 1;
	} else {
		return 0;
	}
}

sub _resource {
	my $self	= shift;
	### uriref | qname
	if ($self->_uriref_test()) {
		return $self->__URI($self->_join_uri($self->{baseURI}, $self->_uriref()));
	} else {
		return $self->__URI($self->_join_uri($self->{baseURI}, $self->_qname()));
	}
}

sub _nodeID_test {
	my $self	= shift;
	### between this (_) and []
	if (substr($self->{tokens}, 0, 1) eq '_') {
		return 1;
	} else {
		return 0;
	}
}

sub _nodeID {
	my $self	= shift;
	### '_:' name
	$self->_eat('_:');
	return $self->_name();
}

sub _qname {
	my $self	= shift;
	### prefixName? ':' name?
	my $prefix	= ($self->{tokens} =~ /^$r_nameStartChar_minus_underscore/) ? $self->_prefixName() : '';
	$self->_eat(':');
	my $name	= ($self->{tokens} =~ /^$r_nameStartChar/) ? $self->_name() : '';
	my $uri		= $self->{bindings}{$prefix};
	return $uri . $name
}

sub _uriref_test {
	my $self	= shift;
	### between this and qname
	if ($self->__startswith('<')) {
		return 1;
	} else {
		return 0;
	}
}

sub _uriref {
	my $self	= shift;
	### '<' relativeURI '>'
	$self->_eat('<');
	my $value	= $self->_relativeURI();
	$self->_eat('>');
	return $value;
}

sub _language {
	my $self	= shift;
	### [a-z]+ ('-' [a-z0-9]+ )*
	my $token	= $self->_eat_re( $r_language );
	return $token;
}

sub _nameStartChar_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_nameStartChar/) {
		return 1;
	} else {
		return 0;
	}
}

sub _nameStartChar {
	my $self	= shift;
	### [A-Z] | "_" | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | 
	### [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] 
	### | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | 
	### [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
	my $nc	= $self->_eat_re( $r_nameStartChar );
	return $nc;
}

sub _nameChar_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_nameStartChar/) {
		return 1;
	} elsif ($self->{tokens} =~ /^$r_nameChar_extra/) {
		return 1;
	} else {
		return 0;
	}
}

sub _nameChar {
	my $self	= shift;
	### nameStartChar | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | 
	### [#x203F-#x2040]
#	if ($self->_nameStartChar_test()) {
	if ($self->{tokens} =~ /^$r_nameStartChar/) {
		my $nc	= $self->_nameStartChar();
		return $nc;
	} else {
		my $nce	= $self->_eat_re( $r_nameChar_extra );
		return $nce;
	}
}

sub _name {
	my $self	= shift;
	### nameStartChar nameChar*
	my ($name)	= ($self->_eat_re( qr/^(${r_nameStartChar}(${r_nameStartChar}|${r_nameChar_extra})*)/ ));
	return $name;
# 	my @parts;
# 	my $nsc	= $self->_nameStartChar();
# 	push(@parts, $nsc);
# #	while ($self->_nameChar_test()) {
# 	while ($self->{tokens} =~ /^$r_nameChar_test/) {
# 		my $nc	= $self->_nameChar();
# 		push(@parts, $nc);
# 	}
# 	return join('', @parts);
}

sub _prefixName_test {
	my $self	= shift;
	### between this and colon
	if ($self->{tokens} =~ /^$r_nameStartChar_minus_underscore/) {
		return 1;
	} else {
		return 0;
	}
}

sub _prefixName {
	my $self	= shift;
	### ( nameStartChar - '_' ) nameChar*
	my @parts;
	my $nsc	= $self->_eat_re( $r_nameStartChar_minus_underscore );
	push(@parts, $nsc);
#	while ($self->_nameChar_test()) {
	while ($self->{tokens} =~ /^$r_nameChar_test/) {
		my $nc	= $self->_nameChar();
		push(@parts, $nc);
	}
	return join('', @parts);
}

sub _relativeURI {
	my $self	= shift;
	### ucharacter*
	my $token	= $self->_eat_re( $r_ucharacters );
	return $token;
}

sub _quotedString_test {
	my $self	= shift;
	if (substr($self->{tokens}, 0, 1) eq '"') {
		return 1;
	} else {
		return 0;
	}
}

sub _quotedString {
	my $self	= shift;
	### string | longString
	if ($self->_longString_test()) {
		return $self->_longString();
	} else {
		return $self->_string();
	}
}

sub _string {
	my $self	= shift;
	### #x22 scharacter* #x22
	$self->_eat('"');
	my $value	= $self->_eat_re( $r_scharacters );
	$self->_eat('"');
	return $self->_parse_short( $value );
}

sub _longString_test {
	my $self	= shift;
	if ($self->__startswith( '"""' )) {
		return 1;
	} else {
		return 0;
	}
}

sub _longString {
	my $self	= shift;
      # #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
	$self->_eat('"""');
	my $value	= $self->_eat_re( $r_lcharacters );
	$self->_eat('"""');
	return $self->_parse_long( $value );
}

################################################################################

use Unicode::Escape;
sub _parse_short {
	my $self	= shift;
	my $s		= shift;
	for ($s) {
		s/\\"/"/g;
		s/\\t/\t/g;
		s/\\r/\r/g;
		s/\\n/\n/g;
	}
	return Unicode::Escape::escape( $s );
}

sub _parse_long {
	my $self	= shift;
	my $s		= shift;
	for ($s) {
		s/\\"/"/g;
		s/\\t/\t/g;
		s/\\r/\r/g;
		s/\\n/\n/g;
	}
	return Unicode::Escape::escape( $s );
}

sub _join_uri {
	my $self	= shift;
	my $base	= shift;
	my $uri		= shift;
	if ($base eq $uri) {
		return $uri;
	}
	return URI->new_abs( $uri, $base );
}

sub _typed {
	my $self		= shift;
	my $value		= shift;
	my $type		= shift;
	my $datatype	= $type->uri_value;
	
	if ($datatype eq "${xsd}integer") {
		$value = int($value);
	} elsif ($datatype eq "${xsd}double") {
	  $value = $value;
	} elsif ($datatype eq "${xsd}decimal") {
		$value = $value;
# 	  context = decimal.Context(17, decimal.ROUND_HALF_DOWN)
# 	  try: $value = str($value.quantize($value, context=context))
# 	  except decimal.InvalidOperation: 
# 		 $value = str($value.normalize(context))
		$value	=~ s/[.]0//;
		if ($value !~ /[.]/) {
			$value = $value . '.0';
		}
	}
	return RDF::Trine::Node::Literal->new($value, undef, $datatype)
}

sub __generate_bnode_id {
	my $self	= shift;
	my $id		= $self->{ bnode_id }++;
	return 'r' . $id;
}

sub __consume_ws {
	my $self	= shift;
	while ($self->{tokens} =~ m/^[\t\r\n #]/) {
		$self->_ws()
	}
}

sub __URI {
	my $self	= shift;
	return RDF::Trine::Node::Resource->new( @_ )
}

sub __bNode {
	my $self	= shift;
	return RDF::Trine::Node::Blank->new( @_ )
}

sub __Literal {
	my $self	= shift;
	return RDF::Trine::Node::Literal->new( @_ )
}

sub __DatatypedLiteral {
	my $self	= shift;
	return RDF::Trine::Node::Literal->new( $_[0], undef, $_[1] )
}


sub __startswith {
	my $self	= shift;
	my $thing	= shift;
	if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
		return 1;
	} else {
		return 0;
	}
}


1;


__END__

class TurtleDocument(object): 
   def __init__(self, uri, input): 
      self.uri = uri
      self.baseURI = uri
      self.input = input
      self.buffer = u''
      self.lines = self.readlines()
      # turtleDoc and ws and long string can read into this
      self.tokens = None 
      self.bindings = {}

   def readlines(self): 
      while True: 
         bytes = self.input.read(8192)
         if not bytes: break
         text = bytes.decode('utf-8')
         self.buffer += text

         while True: 
            m = r_line.match(self.buffer)
            if m: 
               line = m.group(1)
               yield line
               self.buffer = self.buffer[m.end():]
            else: break

      if self.buffer: 
         yield self.buffer
         self.buffer = u''

   def eat(self, thing): 
      if not self.tokens: raise ValueError('No tokens')

      if isinstance(thing, basestring): 
         if self.tokens.startswith(thing): 
            self.tokens = self.tokens[len(thing):]
            return thing
         else: 
            print 'TOKENS: %r' % self.tokens[:50]
            raise ValueError('Expected: %s' % thing)
      elif isinstance(thing, int): 
         token = self.tokens[:thing]
         self.tokens = self.tokens[thing:]
         return token
      elif hasattr(thing, 'pattern'): 
         m = thing.match(self.tokens)
         if m: 
            self.tokens = self.tokens[m.end():]
            return m.group(0)
         raise ValueError('Expected: %s' % thing.pattern)
      print type(thing), thing
      raise Exception

   def test(self, thing): 
      if isinstance(thing, basestring): 
         if self.tokens.startswith(thing): 
            return True
         return False
      print type(thing), thing
      raise Exception

   def triple(self, s, p, o): 
      for t in [type(s), type(p), type(o)]: 
         if t not in (URI, bNode, Literal, DatatypedLiteral): 
            print type(s), type(p), type(o)
            raise Exception('%s %s %s' % (s, p, o))
      print s, p, o, '.'

   def parse(self): 
      self.turtleDoc()

   def turtleDoc(self): 
      # statement*
      try: self.tokens = self.lines.next()
      except StopIteration: return

      while self.statement_test(): 
         self.statement()

   def statement_test(self): 
      if self.tokens: 
         return True
      return False

   def statement(self): 
      # directive ws* '.' ws* | triples ws* '.' ws* | ws+
      if self.directive_test(): 
         self.directive()
         while self.ws_test(): 
            self.ws()
         self.eat('.')
         while self.ws_test(): 
            self.ws()

      elif self.triples_test(): 
         self.triples()
         while self.ws_test(): 
            self.ws()
         self.eat('.')
         while self.ws_test(): 
            self.ws()

      else: 
         self.ws()
         while self.ws_test(): 
            self.ws()

   def directive_test(self): 
      # between directive | triples | ws
      # directives must start with @, triples must not
      if self.tokens.startswith('@'): 
         return True
      return False

   def directive(self): 
      # prefixID | base
      if self.prefixID_test(): 
         self.prefixID()
      else: self.base()

   def prefixID_test(self): 
      # between prefixID | base. prefixID is @prefix, base is @base
      if self.tokens.startswith('@prefix'): 
         return True
      return False

   def prefixID(self): 
      # '@prefix' ws+ prefixName? ':' ws+ uriref
      self.eat('@prefix')
      self.ws()
      while self.ws_test(): 
         self.ws()

      if self.prefixName_test(): 
         prefix = self.prefixName()
      else: prefix = ''

      self.eat(':')
      self.ws()
      while self.ws_test(): 
         self.ws()

      uri = self.uriref()
      self.bindings[prefix] = uri

   def base(self): 
      # '@base' ws+ uriref
      self.eat('@base')
      self.ws()
      while self.ws_test(): 
         self.ws()
      self.baseURI = join(self.baseURI, self.uriref())

   def triples_test(self): 
      # between triples and ws. disjoint, so easy enough
      if self.tokens[0] not in set(['\r', '\n', '\t', ' ', '#']): 
         return True
      return False

   def triples(self): 
      # subject ws+ predicateObjectList
      subj = self.subject()
      self.ws()
      while self.ws_test(): 
         self.ws()
      for (pred, objt) in self.predicateObjectList(): 
         self.triple(subj, pred, objt)

   def predicateObjectList(self): 
      # verb ws+ objectList ( ws* ';' ws* verb ws+ objectList )* (ws* ';')?
      pred = self.verb()
      self.ws()
      while self.ws_test(): 
         self.ws()
      for objt in self.objectList(): 
         yield (pred, objt)

      while self.ws_test() or self.test(';'): 
         while self.ws_test(): 
            self.ws()
         self.eat(';')

         while self.ws_test(): 
            self.ws()

         if self.verb_test(): # @@
            pred = self.verb()
            self.ws()
            while self.ws_test(): 
               self.ws()
            for objt in self.objectList(): 
               yield (pred, objt)
         else: break

   def objectList(self): 
      # object (ws* ',' ws* object)*
      yield self.object()
      while self.ws_test(): 
         self.ws()
      while self.test(','): 
         while self.ws_test(): 
            self.ws()
         self.eat(',')
         while self.ws_test(): 
            self.ws()
         yield self.object()
         while self.ws_test(): 
            self.ws()

   def verb_test(self): 
      if self.tokens[0] != '.': 
         return True
      return False

   def verb(self): 
      # predicate | a
      if self.predicate_test(): 
         return self.predicate()
      else: 
         self.eat('a')
         return URI(rdf + 'type')

   def comment(self): 
      # '#' ( [^#xA#xD] )*
      self.eat(r_comment)

   def subject(self): 
      # resource | blank
      if self.resource_test(): 
         return self.resource()
      else: return self.blank()

   def predicate_test(self): 
      # between this and 'a'... a little tricky
      # if it's a, it'll be followed by whitespace; whitespace is mandatory
      # after a verb, which is the only thing predicate appears in
      if not self.tokens.startswith('a'): 
         return True
      elif self.tokens[1] not in set(['\r', '\n', '\t', ' ', '#']): 
         return True
      return False

   def predicate(self): 
      # resource
      return self.resource()

   def object(self): 
      # resource | blank | literal
      if self.resource_test(): 
         return self.resource()
      elif self.blank_test(): 
         return self.blank()
      else: return self.literal()

   def literal(self): 
      # quotedString ( '@' language )? | datatypeString | integer | 
      # double | decimal | boolean
      # datatypeString = quotedString '^^' resource      
      # (so we change this around a bit to make it parsable without a huge 
      # multiple lookahead)

      if self.quotedString_test(): 
         value = self.quotedString()

         if self.test('@'): 
            self.eat('@')
            lang = self.language()
            return Literal(value, lang)
         elif self.test('^^'): 
            self.eat('^^')
            dtype = self.resource()
            return typed(value, dtype)
         else: return Literal(value, None)

      elif self.double_test(): 
         return self.double()

      elif self.decimal_test(): 
         return self.decimal()

      elif self.integer_test(): 
         return self.integer()

      else: return self.boolean()

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

   def double_test(self): 
      if r_double.match(self.tokens): 
         return True
      return False

   def double(self): 
      # ('-' | '+') ? ( [0-9]+ '.' [0-9]* exponent | '.' ([0-9])+ exponent 
      # | ([0-9])+ exponent )
      # exponent = [eE] ('-' | '+')? [0-9]+
      token = self.eat(r_double)
      return typed(token, xsd + 'double')

   def decimal_test(self): 
      if r_decimal.match(self.tokens): 
         return True
      return False

   def decimal(self): 
      # ('-' | '+')? ( [0-9]+ '.' [0-9]* | '.' ([0-9])+ | ([0-9])+ )
      token = self.eat(r_decimal)
      return typed(token, xsd + 'decimal')

   def integer_test(self): 
      if r_integer.match(self.tokens): 
         return True
      return False

   def integer(self): 
      # ('-' | '+') ? [0-9]+
      token = self.eat(r_integer)
      return typed(token, xsd + 'integer')

   def boolean(self): 
      # 'true' | 'false'
      token = self.eat(r_boolean)
      return DatatypedLiteral(token, xsd + 'boolean')

   def blank_test(self): 
      # between this and literal. urgh!
      # this can start with...
      # _ | [ | (
      # literal can start with...
      # * " | + | - | digit | t | f
      if self.tokens[0] in set(['_', '[', '(']): 
         return True
      return False

   def blank(self): 
      # nodeID | '[]' | '[' ws* predicateObjectList ws* ']' | collection
      if self.nodeID_test(): 
         return bNode(self.nodeID())

      elif self.test('[]'): 
         self.eat('[]')
         return bNode(generate_bnode_id())

      elif self.test('['): 
         self.eat('[')
         subj = bNode(generate_bnode_id())
         while self.ws_test(): 
            self.ws()
         for (pred, objt) in self.predicateObjectList(): 
            self.triple(subj, pred, objt)
         while self.ws_test(): 
            self.ws()
         self.eat(']')
         return subj

      else: return self.collection()

   def itemList_test(self): 
      # between this and whitespace or ')'
      if self.tokens[0] not in set('\r\n\t #)'): 
         return True
      return False

   def itemList(self): 
      # object (ws+ object)*
      yield self.object()
      while self.ws_test(): 
         self.ws()
         while self.ws_test(): 
            self.ws()
         if not self.test(')'): 
            yield self.object()

   def collection(self): 
      # '(' ws* itemList? ws* ')'
      b = bNode(generate_bnode_id())
      this, rest = b, None
      self.eat('(')
      while self.ws_test(): 
         self.ws()
      if self.itemList_test(): 
         for objt in self.itemList(): 
            if rest is not None: 
               this = bNode(generate_bnode_id())
               self.triple(rest, URI(rdf + 'rest'), this)
            self.triple(this, URI(rdf + 'first'), objt)
            rest = this
      if rest is not None: 
         self.triple(rest, URI(rdf + 'rest'), URI(rdf + 'nil'))
      else: b = URI(rdf + 'nil')
      while self.ws_test(): 
         self.ws()
      self.eat(')')
      return b

   def ws_test(self): 
      if not self.tokens: 
         return False # @@@@@@@@@

      if self.tokens[0] in set(['\t', '\r', '\n', ' ', '#']): 
         return True
      return False

   def ws(self): 
      # #x9 | #xA | #xD | #x20 | comment
      if self.test('#'): 
         self.comment()
      else: self.eat(1)

      if not self.tokens: 
         try: self.tokens = self.lines.next()
         except StopIteration: return

   def resource_test(self): 
      # between this and blank and literal
      # quotedString ( '@' language )? | datatypeString | integer |
      # double | decimal | boolean
      # datatypeString = quotedString '^^' resource

      r_booltest = re.compile(r'(true|false)\b')
      if self.tokens[0] not in set('_[("+-0123456789') and \
         not r_booltest.match(self.tokens): 
         return True
      return False

   def resource(self): 
      # uriref | qname
      if self.uriref_test(): 
         return URI(join(self.baseURI, self.uriref()))
      else: return URI(join(self.baseURI, self.qname()))

   def nodeID_test(self): 
      # between this (_) and []
      if self.tokens[0] == '_': 
         return True
      return False

   def nodeID(self): 
      # '_:' name
      self.eat('_:')
      return self.name()

   def qname(self): 
      # prefixName? ':' name?
      if self.prefixName_test(): 
         prefix = self.prefixName()
      else: prefix = ''

      self.eat(':')

      if self.name_test(): 
         name = self.name()
      else: name = ''
      uri = self.bindings[prefix]
      return uri + name

   def uriref_test(self): 
      # between this and qname
      if self.tokens.startswith('<'): 
         return True
      return False

   def uriref(self): 
      # '<' relativeURI '>'
      self.eat('<')
      value = self.relativeURI()
      self.eat('>')
      return value

   def language(self): 
      # [a-z]+ ('-' [a-z0-9]+ )*
      token = self.eat(r_language)
      return token

   def nameStartChar_test(self): 
      if r_nameStartChar.match(self.tokens): 
         return True
      return False

   def nameStartChar(self): 
      # [A-Z] | "_" | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | 
      # [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] 
      # | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | 
      # [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
      nc = self.eat(r_nameStartChar)
      return nc

   def nameChar_test(self): 
      if r_nameStartChar.match(self.tokens): 
         return True
      elif r_nameChar_extra.match(self.tokens): 
         return True
      return False

   def nameChar(self): 
      # nameStartChar | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | 
      # [#x203F-#x2040]
      if self.nameStartChar_test(): 
         nc = self.nameStartChar()
         return nc
      else: 
         nce = self.eat(r_nameChar_extra)
         return nce

   def name_test(self): 
      # between this and ws?
      if r_nameStartChar.match(self.tokens): 
         return True
      return False

   def name(self): 
      # nameStartChar nameChar*
      parts = []

      nsc = self.nameStartChar()
      parts.append(nsc)

      while self.nameChar_test(): 
         nc = self.nameChar()
         parts.append(nc)
      return ''.join(parts)

   def prefixName_test(self): 
      # between this and colon
      if r_nameStartChar_minus_underscore.match(self.tokens): 
         return True
      return False

   def prefixName(self): 
      # ( nameStartChar - '_' ) nameChar*
      parts = []
      nscmu = self.eat(r_nameStartChar_minus_underscore)
      parts.append(nscmu)
      while self.nameChar_test(): 
         nc = self.nameChar()
         parts.append(nc)
      return ''.join(parts)

   def relativeURI(self): 
      # ucharacter*
      token = self.eat(r_ucharacters)
      return token

   def quotedString_test(self): 
      if self.tokens[0] == '"': 
         return True
      return False

   def quotedString(self): 
      # string | longString
      if self.longString_test(): 
         return self.longString()
      else: return self.string()

   def string(self): 
      # #x22 scharacter* #x22
      self.eat('"')
      value = self.eat(r_scharacters)
      self.eat('"')
      return parse_short(value)

   def longString_test(self): 
      if self.tokens.startswith('"""'): 
         return True
      return False

   def longString(self): 
      # #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
      while self.tokens.count('"""') < 2: 
         self.tokens += self.lines.next()
      self.eat('"""')
      value = self.eat(r_lcharacters)
      self.eat('"""')
      return parse_long(value)
