package RDF::Parser::Turtle;

use strict;
use warnings;

BEGIN {
	foreach my $t ('turtle', 'application/x-turtle', 'application/turtle') {
		$RDF::Parser::types{ $t }	= __PACKAGE__;
	}
}


use URI;
use RDF::Namespace;
use RDF::Query::Node;
use RDF::Parser::Error;
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
my $xsd			= RDF::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $rdf			= RDF::Namespace->new('http://www.w3.org/2001/XMLSchema#');

sub new {
	my $class	= shift;
	my $uri		= shift || 'http://example.com/';
	my $input	= shift;
	my $self	= bless({
					bindings	=> {},
					bnode_id	=> 0,
				}, $class);
	return $self;
}

sub parse {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	local($self->{baseURI})	= $uri;
	local($self->{tokens})	= $input;
	return $self->turtleDoc();
}

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

sub eat {
	my $self	= shift;
	my $thing	= shift;
	if (not(length($self->{tokens}))) {
		Carp::cluck("no tokens left ($thing)") if ($debug);
		throw RDF::Parser::Error::ValueError -text => "No tokens";
	}
	
	if (substr($self->{tokens}, 0, 1) eq '^') {
		Carp::cluck( "eating $thing with input $self->{tokens}" );
	}
	
	if (blessed($thing) and $thing->isa('Regexp')) {
		if ($self->{tokens} =~ /^$thing/) {
			my $match	= $&;
			substr($self->{tokens}, 0, length($match))	= '';
			return $match;
		}
		Carp::cluck("Expected ($thing)") if ($debug);
		throw RDF::Parser::Error::ValueError -text => "Expected: $thing";
	} elsif (looks_like_number( $thing )) {
		my ($token)	= substr( $self->{tokens}, 0, $thing, '' );
		return $token
	} else {
		### thing is a string
		if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
			substr($self->{tokens}, 0, length($thing))	= '';
			return $thing;
		} else {
			Carp::cluck("expected: $thing, got: $self->{tokens}") if ($debug);
			throw RDF::Parser::Error::ValueError("Expected: $thing")
		}
	}
	print $thing;
	throw Error;
}

sub test {
	my $self	= shift;
	my $thing	= shift;
	if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
		return 1;
	} else {
		return 0;
	}
}

sub triple {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	foreach my $n ($s, $p, $o) {
		unless (blessed($n) and $n->isa('RDF::Query::Node')) {
			throw RDF::Parser::Error;
		}
	}
	
	if (my $code = $self->{handle_triple}) {
		my $st	= RDF::Query::Algebra::Triple->new( $s, $p, $o );
		$code->( $st );
	}
	
	my $count	= ++$self->{triple_count};
	warn "$count\n" if ($debug);
#	print join(' ', map { $_->sse } ($s, $p, $o)), '.' . "\n";
}

sub turtleDoc {
	my $self	= shift;
	while ($self->statement_test()) {
		$self->statement();
	}
}

sub statement_test {
	my $self	= shift;
	if (length($self->{tokens})) {
		return 1;
	} else {
		return 0;
	}
}

sub statement {
	my $self	= shift;
	if ($self->directive_test()) {
		$self->directive();
		$self->_consume_ws();
		$self->eat('.');
		$self->_consume_ws();
	} elsif ($self->triples_test()) {
		$self->triples();
		$self->_consume_ws();
		$self->eat('.');
		$self->_consume_ws();
	}  else {
		$self->ws();
		$self->_consume_ws();
	}
}

sub directive_test {
	my $self	= shift;
	### between directive | triples | ws
	### directives must start with @, triples must not
	if ($self->_startswith('@')) {
		return 1;
	} else {
		return 0;
	}
}

sub directive {
	my $self	= shift;
	### prefixID | base
	if ($self->prefixID_test()) {
		$self->prefixID();
	} else {
		$self->base();
	}
}

sub prefixID_test {
	my $self	= shift;
	### between prefixID | base. prefixID is @prefix, base is @base
	if ($self->_startswith('@prefix')) {
		return 1;
	} else {
		return 0;
	}
}

sub prefixID {
	my $self	= shift;
	### '@prefix' ws+ prefixName? ':' ws+ uriref
	$self->eat('@prefix');
	$self->ws();
	while ($self->ws_test()) {
		$self->ws()
	}
	
	my $prefix;
	if ($self->prefixName_test()) {
		$prefix = $self->prefixName();
	} else {
		$prefix	= '';
	}
	
	$self->eat(':');
	$self->ws();
	while ($self->ws_test()) {
		$self->ws();
	}
	
	my $uri = $self->uriref();
	$self->{bindings}{$prefix}	= $uri;
}



sub base {
	my $self	= shift;
	### '@base' ws+ uriref
	$self->eat('@base');
	$self->ws();
	$self->_consume_ws();
	$self->{baseURI}	=	$self->join_uri($self->{baseURI}, $self->uriref()->uri_value);
}

sub triples_test {
	my $self	= shift;
	### between triples and ws. disjoint, so easy enough
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ /^[\r\n\t #]/) {
		return 1;
	} else {
		return 0;
	}
}

sub triples {
	my $self	= shift;
	### subject ws+ predicateObjectList
	my $subj	= $self->subject();
	$self->ws();
	$self->_consume_ws;
	foreach my $data ($self->predicateObjectList()) {
		my ($pred, $objt)	= @$data;
		$self->triple( $subj, $pred, $objt );
	}
}

sub predicateObjectList {
	my $self	= shift;
	### verb ws+ objectList ( ws* ';' ws* verb ws+ objectList )* (ws* ';')?
	my $pred = $self->verb();
	$self->ws();
	$self->_consume_ws();
	
	my @list;
	foreach my $objt ($self->objectList()) {
		push(@list, [$pred, $objt]);
	}
	
	while ($self->ws_test() or $self->test(';')) {
		$self->_consume_ws();
		$self->eat(';');
		$self->_consume_ws();
		if ($self->verb_test()) { # @@
			$pred = $self->verb();
			$self->ws();
			$self->_consume_ws();
			foreach my $objt ($self->objectList()) {
				push(@list, [$pred, $objt]);
			}
		} else {
			last
		}
	}
	
	return @list;
}

sub objectList {
	my $self	= shift;
	### object (ws* ',' ws* object)*
	my @list;
	push(@list, $self->object());
	$self->_consume_ws();
	while ($self->test(',')) {
		$self->_consume_ws();
		$self->eat(',');
		$self->_consume_ws();
		push(@list, $self->object());
		$self->_consume_ws();
	}
	return @list;
}

sub verb_test {
	my $self	= shift;
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ /^[.]/) {
		return 1;
	} else {
		return 0;
	}
}

sub verb {
	my $self	= shift;
	### predicate | a
	if ($self->predicate_test()) {
		return $self->predicate();
	} else {
		$self->eat('a');
		return $rdf->type;
	}
}

sub comment {
	my $self	= shift;
	### '#' ( [^#xA#xD] )*
	$self->eat($r_comment);
}

sub subject {
	my $self	= shift;
	### resource | blank
#	if ($self->resource_test()) {
	if (length($self->{tokens}) and $self->{tokens} =~ /^$r_resource_test/) {
		return $self->resource();
	} else {
		return $self->blank();
	}
}

sub predicate_test {
	my $self	= shift;
	### between this and 'a'... a little tricky
	### if it's a, it'll be followed by whitespace; whitespace is mandatory
	### after a verb, which is the only thing predicate appears in
	return 0 unless (length($self->{tokens}));
	if (not $self->_startswith('a')) {
		return 1
	} elsif ($self->{tokens} !~ m/^a[\r\n\t #]/) {
		return 1
	} else {
		return 0
	}
}

sub predicate {
	my $self	= shift;
	### resource
	return $self->resource();
}

sub object {
	my $self	= shift;
	### resource | blank | literal
#	if ($self->resource_test()) {
	if (length($self->{tokens}) and $self->{tokens} =~ /^$r_resource_test/) {
		return $self->resource();
	} elsif ($self->blank_test()) {
		return $self->blank();
	} else {
		return $self->literal();
	}
}

sub literal {
	my $self	= shift;
	### quotedString ( '@' language )? | datatypeString | integer | 
	### double | decimal | boolean
	### datatypeString = quotedString '^^' resource      
	### (so we change this around a bit to make it parsable without a huge 
	### multiple lookahead)
	
	if ($self->quotedString_test()) {
		my $value = $self->quotedString();
		if ($self->test('@')) {
			$self->eat('@');
			my $lang = $self->language();
			return $self->_Literal($value, $lang);
		} elsif ($self->test('^^')) {
			$self->eat('^^');
			my $dtype = $self->resource();
			return $self->typed($value, $dtype);
		} else {
			return $self->_Literal($value);
		}
	} elsif ($self->double_test()) {
		return $self->double();
	} elsif ($self->decimal_test()) {
		return $self->decimal();
	} elsif ($self->integer_test()) {
		return $self->integer();
	} else {
		return $self->boolean();
	}
}

sub double_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_double/) {
		return 1;
	} else {
		return 0;
	}
}

sub double {
	my $self	= shift;
	### ('-' | '+') ? ( [0-9]+ '.' [0-9]* exponent | '.' ([0-9])+ exponent 
	### | ([0-9])+ exponent )
	### exponent = [eE] ('-' | '+')? [0-9]+
	my $token	= $self->eat( $r_double );
	return $self->typed( $token, $xsd->double );
}

sub decimal_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_decimal/) {
		return 1;
	} else {
		return 0;
	}
}

sub decimal {
	my $self	= shift;
	### ('-' | '+')? ( [0-9]+ '.' [0-9]* | '.' ([0-9])+ | ([0-9])+ )
	my $token	= $self->eat( $r_decimal );
	return $self->typed( $token, $xsd->decimal );
}

sub integer_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_integer/) {
		return 1;
	} else {
		return 0;
	}
}

sub integer {
	my $self	= shift;
	### ('-' | '+')? ( [0-9]+ '.' [0-9]* | '.' ([0-9])+ | ([0-9])+ )
	my $token	= $self->eat( $r_integer );
	return $self->typed( $token, $xsd->integer );
}

sub boolean {
	my $self	= shift;
	### 'true' | 'false'
	my $token	= $self->eat( $r_boolean );
	return $self->typed( $token, $xsd->boolean );
}

sub blank_test {
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

sub blank {
	my $self	= shift;
	### nodeID | '[]' | '[' ws* predicateObjectList ws* ']' | collection
	if ($self->nodeID_test) {
		return $self->_bNode($self->nodeID());
	} elsif ($self->test('[]')) {
		$self->eat('[]');
		return $self->_bNode( $self->_generate_bnode_id() );
	} elsif ($self->test('[')) {
		$self->eat('[');
		my $subj	= $self->_bNode( $self->_generate_bnode_id() );
		$self->_consume_ws();
		foreach my $data ($self->predicateObjectList()) {
			my ($pred, $objt)	= @$data;
			$self->triple( $subj, $pred, $objt );
		}
		$self->_consume_ws();
		$self->eat(']');
		return $subj;
	} else {
		return $self->collection();
	}
}

sub itemList_test {
	my $self	= shift;
	### between this and whitespace or ')'
	return 0 unless (length($self->{tokens}));
	if ($self->{tokens} !~ m/^[\r\n\t #)]/) {
		return 1;
	} else {
		return 0;
	}
}

sub itemList {
	my $self	= shift;
	### object (ws+ object)*
	my @list;
	push(@list, $self->object());
	while ($self->ws_test()) {
		$self->ws();
		$self->_consume_ws();
		if (not $self->test(')')) {
			push(@list, $self->object());
		}
	}
	return @list;
}

sub collection {
	my $self	= shift;
	### '(' ws* itemList? ws* ')'
	my $b	= $self->_bNode( $self->_generate_bnode_id() );
	my ($this, $rest)	= ($b, undef);
	$self->eat('(');
	$self->_consume_ws();
	if ($self->itemList_test()) {
#		while (my $objt = $self->itemList()) {
		foreach my $objt ($self->itemList()) {
			if (defined($rest)) {
				$this	= $self->_bNode( $self->_generate_bnode_id() );
				$self->triple( $rest, $rdf->rest, $this)
			}
			$self->triple( $this, $rdf->first, $objt );
			$rest = $this;
		}
	}
	if (defined($rest)) {
		$self->triple( $rest, $rdf->rest, $rdf->nil );
	} else {
		$b = $rdf->nil;
	}
	$self->_consume_ws();
	$self->eat(')');
	return $b;
}

sub ws_test {
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

sub ws {
	my $self	= shift;
	### #x9 | #xA | #xD | #x20 | comment
	if ($self->test('#')) {
		$self->comment();
	} else {
		my $ws	= $self->eat(1);
		unless ($ws =~ /^[\n\r\t ]/) {
			throw RDF::Parser::Error::ValueError -text => 'Not whitespace';
		}
	}
}

sub resource_test {
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

sub resource {
	my $self	= shift;
	### uriref | qname
	if ($self->uriref_test()) {
		return $self->_URI($self->join_uri($self->{baseURI}, $self->uriref()));
	} else {
		return $self->_URI($self->join_uri($self->{baseURI}, $self->qname()));
	}
}

sub nodeID_test {
	my $self	= shift;
	### between this (_) and []
	if (substr($self->{tokens}, 0, 1) eq '_') {
		return 1;
	} else {
		return 0;
	}
}

sub nodeID {
	my $self	= shift;
	### '_:' name
	$self->eat('_:');
	return $self->name();
}

sub qname {
	my $self	= shift;
	### prefixName? ':' name?
	my $prefix	= ($self->prefixName_test()) ? $self->prefixName() : '';
	$self->eat(':');
	my $name	= ($self->{tokens} =~ /^$r_nameStartChar/) ? $self->name() : '';
	my $uri		= $self->{bindings}{$prefix};
	return $uri . $name
}

sub uriref_test {
	my $self	= shift;
	### between this and qname
	if ($self->_startswith('<')) {
		return 1;
	} else {
		return 0;
	}
}

sub uriref {
	my $self	= shift;
	### '<' relativeURI '>'
	$self->eat('<');
	my $value	= $self->relativeURI();
	$self->eat('>');
	return $value;
}

sub language {
	my $self	= shift;
	### [a-z]+ ('-' [a-z0-9]+ )*
	my $token	= $self->eat( $r_language );
	return $token;
}

sub nameStartChar_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_nameStartChar/) {
		return 1;
	} else {
		return 0;
	}
}

sub nameStartChar {
	my $self	= shift;
	### [A-Z] | "_" | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | 
	### [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] 
	### | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | 
	### [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
	my $nc	= $self->eat( $r_nameStartChar );
	return $nc;
}

sub nameChar_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^$r_nameStartChar/) {
		return 1;
	} elsif ($self->{tokens} =~ /^$r_nameChar_extra/) {
		return 1;
	} else {
		return 0;
	}
}

sub nameChar {
	my $self	= shift;
	### nameStartChar | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | 
	### [#x203F-#x2040]
#	if ($self->nameStartChar_test()) {
	if ($self->{tokens} =~ /^$r_nameStartChar/) {
		my $nc	= $self->nameStartChar();
		return $nc;
	} else {
		my $nce	= $self->eat( $r_nameChar_extra );
		return $nce;
	}
}

sub name {
	my $self	= shift;
	### nameStartChar nameChar*
	my ($name)	= ($self->eat( qr/^(${r_nameStartChar}(${r_nameStartChar}|${r_nameChar_extra})*)/ ));
	return $name;
# 	my @parts;
# 	my $nsc	= $self->nameStartChar();
# 	push(@parts, $nsc);
# #	while ($self->nameChar_test()) {
# 	while ($self->{tokens} =~ /^$r_nameChar_test/) {
# 		my $nc	= $self->nameChar();
# 		push(@parts, $nc);
# 	}
# 	return join('', @parts);
}

sub prefixName_test {
	my $self	= shift;
	### between this and colon
	if ($self->{tokens} =~ /^$r_nameStartChar_minus_underscore/) {
		return 1;
	} else {
		return 0;
	}
}

sub prefixName {
	my $self	= shift;
	### ( nameStartChar - '_' ) nameChar*
	my @parts;
	my $nsc	= $self->eat( $r_nameStartChar_minus_underscore );
	push(@parts, $nsc);
#	while ($self->nameChar_test()) {
	while ($self->{tokens} =~ /^$r_nameChar_test/) {
		my $nc	= $self->nameChar();
		push(@parts, $nc);
	}
	return join('', @parts);
}

sub relativeURI {
	my $self	= shift;
	### ucharacter*
	my $token	= $self->eat( $r_ucharacters );
	return $token;
}

sub quotedString_test {
	my $self	= shift;
	if (substr($self->{tokens}, 0, 1) eq '"') {
		return 1;
	} else {
		return 0;
	}
}

sub quotedString {
	my $self	= shift;
	### string | longString
	if ($self->longString_test()) {
		return $self->longString();
	} else {
		return $self->string();
	}
}

sub string {
	my $self	= shift;
	### #x22 scharacter* #x22
	$self->eat('"');
	my $value	= $self->eat( $r_scharacters );
	$self->eat('"');
	return $self->parse_short( $value );
}

sub longString_test {
	my $self	= shift;
	if ($self->_startswith( '"""' )) {
		return 1;
	} else {
		return 0;
	}
}

sub longString {
	my $self	= shift;
      # #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
	$self->eat('"""');
	my $value	= $self->eat( $r_lcharacters );
	$self->eat('"""');
	return $self->parse_long( $value );
}

################################################################################

use Unicode::Escape;
sub parse_short {
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

sub parse_long {
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

sub join_uri {
	my $self	= shift;
	my $base	= shift;
	my $uri		= shift;
	if ($base eq $uri) {
		return $uri;
	}
	return URI->new_abs( $uri, $base );
}

sub typed {
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
	return RDF::Query::Node::Literal->new($value, undef, $datatype)
}

sub _generate_bnode_id {
	my $self	= shift;
	my $id		= $self->{ bnode_id }++;
	return 'r' . $id;
}

sub _consume_ws {
	my $self	= shift;
	while ($self->ws_test()) {
		$self->ws()
	}
}

sub _URI {
	my $self	= shift;
	return RDF::Query::Node::Resource->new( @_ )
}

sub _bNode {
	my $self	= shift;
	return RDF::Query::Node::Blank->new( @_ )
}

sub _Literal {
	my $self	= shift;
	return RDF::Query::Node::Blank->new( @_ )
}

sub _DatatypedLiteral {
	my $self	= shift;
	return RDF::Query::Node::Blank->new( $_[0], undef, $_[1] )
}


sub _startswith {
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
