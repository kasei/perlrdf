# RDF::Trine::Parser::Turtle
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::Turtle - Turtle RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::Turtle version 0.138

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::Turtle;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use base qw(RDF::Trine::Parser);

use URI;
use Encode;
use Log::Log4perl;
use Scalar::Util qw(blessed looks_like_number);
use URI::Escape qw(uri_unescape);

use RDF::Trine qw(literal);
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Error;

our ($VERSION, $rdf, $xsd);
our ($r_boolean, $r_comment, $r_decimal, $r_double, $r_integer, $r_language, $r_lcharacters, $r_line, $r_nameChar_extra, $r_nameStartChar_minus_underscore, $r_scharacters, $r_ucharacters, $r_booltest, $r_nameStartChar, $r_nameChar, $r_prefixName, $r_qname, $r_resource_test, $r_nameChar_test);
BEGIN {
	$VERSION				= '0.138';
	foreach my $ext (qw(ttl)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	$RDF::Trine::Parser::parser_names{ 'turtle' }	= __PACKAGE__;
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::encodings{ $class }		= 'utf8';
	$RDF::Trine::Parser::format_uris{ 'http://www.w3.org/ns/formats/Turtle' }	= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'text/turtle';
	foreach my $type (qw(application/x-turtle application/turtle text/turtle)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
	
	$rdf			= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
	$xsd			= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');
	
	$r_boolean				= qr'(?:true|false)';
	$r_comment				= qr'#[^\r\n]*';
	$r_decimal				= qr'[+-]?([0-9]+\.[0-9]*|\.([0-9])+)';
	$r_double				= qr'[+-]?([0-9]+\.[0-9]*[eE][+-]?[0-9]+|\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)';
	$r_integer				= qr'[+-]?[0-9]+';
	$r_language				= qr'[a-z]+(-[a-z0-9]+)*'i;
	$r_lcharacters			= qr'(?s)[^"\\]*(?:(?:\\.|"(?!""))[^"\\]*)*';
	$r_line					= qr'(?:[^\r\n]+[\r\n]+)(?=[^\r\n])';
	$r_nameChar_extra		= qr'[-0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]';
	$r_nameStartChar_minus_underscore	= qr'[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]';
	$r_scharacters			= qr'[^"\\]*(?:\\.[^"\\]*)*';
	$r_ucharacters			= qr'[^>\\]*(?:\\.[^>\\]*)*';
	$r_booltest				= qr'(?:true|false)\b';
	$r_nameStartChar		= qr/[A-Za-z_\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]/;
	$r_nameChar				= qr/${r_nameStartChar}|[-0-9\x{b7}\x{0300}-\x{036f}\x{203F}-\x{2040}]/;
	$r_prefixName			= qr/(?:(?!_)${r_nameStartChar})($r_nameChar)*/;
	$r_qname				= qr/(?:${r_prefixName})?:/;
	$r_resource_test		= qr/<|$r_qname/;
	$r_nameChar_test		= qr"(?:$r_nameStartChar|$r_nameChar_extra)";
}

=item C<< new >>

Returns a new Turtle parser.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $prefix	= '';
	if (defined($args{ bnode_prefix })) {
		$prefix	= $args{ bnode_prefix };
	} else {
		$prefix	= $class->new_bnode_prefix();
	}
	my $self	= bless({
					bindings		=> {},
					bnode_id		=> 0,
					bnode_prefix	=> $prefix,
					@_
				}, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	my $handler	= shift;
	local($self->{handle_triple});
	if ($handler) {
		$self->{handle_triple}	= $handler;
	}
	local($self->{baseURI})	= $uri;
	
	$input	= '' unless (defined($input));
	$input	=~ s/^\x{FEFF}//;
	
	local($self->{tokens})	= $input;
	$self->_Document();
	return;
}

=item C<< parse_node ( $string [, $base_uri] ) >>

Parses and returns a L<RDF::Trine::Node> object that is serialized in
C<< $string >> in Turtle syntax.

=cut

sub parse_node {
	my $self	= shift;
	my $input	= shift;
	my $uri		= shift;
	local($self->{handle_triple});
	local($self->{baseURI})	= $uri;
	$input	=~ s/^\x{FEFF}//;
	local($self->{tokens})	= $input;
	return $self->_object();
}

sub _eat_re {
	my $self	= shift;
	my $thing	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.turtle");
	if (not(length($self->{tokens}))) {
		$l->error("no tokens left ($thing)");
		throw RDF::Trine::Error::ParserError -text => "No tokens";
	}
	
	if ($self->{tokens} =~ m/^($thing)/) {
		my $match	= $1;
		substr($self->{tokens}, 0, length($match))	= '';
		return;
	}
	$l->error("Expected ($thing) with remaining: $self->{tokens}");
	throw RDF::Trine::Error::ParserError -text => "Expected: $thing";
}

sub _eat_re_save {
	my $self	= shift;
	my $thing	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.turtle");
	if (not(length($self->{tokens}))) {
		$l->error("no tokens left ($thing)");
		throw RDF::Trine::Error::ParserError -text => "No tokens";
	}
	
	if ($self->{tokens} =~ m/^($thing)/) {
		my $match	= $1;
		substr($self->{tokens}, 0, length($match))	= '';
		return $match;
	}
	$l->error("Expected ($thing) with remaining: $self->{tokens}");
	throw RDF::Trine::Error::ParserError -text => "Expected: $thing";
}

sub _eat {
	my $self	= shift;
	my $thing	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.turtle");
	if (not(length($self->{tokens}))) {
		$l->error("no tokens left ($thing)");
		throw RDF::Trine::Error::ParserError -text => "No tokens";
	}
	
	### thing is a string
	if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
		substr($self->{tokens}, 0, length($thing))	= '';
		return;
	} else {
		
		$l->logcluck("expected: $thing, got: $self->{tokens}");
		throw RDF::Trine::Error::ParserError -text => "Expected: $thing";
	}
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
		unless ($n->isa('RDF::Trine::Node')) {
			throw RDF::Trine::Error::ParserError;
		}
	}
	
	if ($self->{canonicalize}) {
		if ($o->isa('RDF::Trine::Node::Literal') and $o->has_datatype) {
			my $value	= $o->literal_value;
			my $dt		= $o->literal_datatype;
			my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
			$o	= literal( $canon, undef, $dt );
		}
	}
	my $st	= RDF::Trine::Statement->new( $s, $p, $o );
	if (my $code = $self->{handle_triple}) {
		$code->( $st );
	}
	
	my $count	= ++$self->{triple_count};
}

sub _Document {
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
	
	if (blessed(my $ns = $self->{namespaces})) {
		unless ($ns->namespace_uri($prefix)) {
			$ns->add_mapping( $prefix => $uri );
		}
	}
}



sub _base {
	my $self	= shift;
	### '@base' ws+ uriref
	$self->_eat('@base');
	$self->_ws();
	$self->__consume_ws();
	my $uri	= $self->_uriref();
	if (ref($uri)) {
		$uri	= $uri->uri_value;
	}
	$self->{baseURI}	=	$self->_join_uri($self->{baseURI}, $uri);
}

sub _triples_test {
	my $self	= shift;
	return 1 if $self->_resource_test;
	return $self->_blank_test;
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
	return 1 if ($self->{tokens} =~ /^a\b/);
	return $self->_predicate_test();
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
	return 1;
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
	return $self->_resource_test;
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
	my $token	= $self->_eat_re_save( $r_double );
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
	my $token	= $self->_eat_re_save( $r_decimal );
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
	my $token	= $self->_eat_re_save( $r_integer );
	return $self->_typed( $token, $xsd->integer );
}

sub _boolean {
	my $self	= shift;
	### 'true' | 'false'
	my $token	= $self->_eat_re_save( $r_boolean );
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
		return $self->__bNode( $self->__anonimize_bnode_id( $self->_nodeID() ) );
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
		my $ws	= $self->_eat_re_save( qr/[\n\r\t ]+/ );
		unless ($ws =~ /^[\n\r\t ]/) {
			throw RDF::Trine::Error::ParserError -text => 'Not whitespace';
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
	if ($self->{tokens} =~ m/^$r_resource_test/) {
		return 1;
	} else {
		return 0;
	}
}

sub _resource {
	my $self	= shift;
	### uriref | qname
	if ($self->_uriref_test()) {
		my $uri	= $self->_uriref();
		return $self->__URI($uri, $self->{baseURI});
	} else {
		my $qname	= $self->_qname();
		my $base	= $self->{baseURI};
		return $self->__URI($qname, $base);
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
	unless (exists $self->{bindings}{$prefix}) {
		throw RDF::Trine::Error::ParserError -text => "Undeclared prefix $prefix";
	}
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
	my $uri	= uri_unescape(encode_utf8($value));
	my $uni	= decode_utf8($uri);
	return $uni;
}

sub _language {
	my $self	= shift;
	### [a-z]+ ('-' [a-z0-9]+ )*
	my $token	= $self->_eat_re_save( $r_language );
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
	my $nc	= $self->_eat_re_save( $r_nameStartChar );
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
		my $nce	= $self->_eat_re_save( $r_nameChar_extra );
		return $nce;
	}
}

sub _name {
	my $self	= shift;
	### nameStartChar nameChar*
	my $name	= $self->_eat_re_save( qr/^${r_nameStartChar}(${r_nameStartChar}|${r_nameChar_extra})*/ );
	return $name;
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
	my $nsc	= $self->_eat_re_save( $r_nameStartChar_minus_underscore );
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
	my $token	= $self->_eat_re_save( $r_ucharacters );
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
	my $value	= $self->_eat_re_save( $r_scharacters );
	$self->_eat('"');
	my $string	= $self->_parse_short( $value );
	return $string;
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
	my $value	= $self->_eat_re_save( $r_lcharacters );
	$self->_eat('"""');
	my $string	= $self->_parse_long( $value );
	return $string;
}

################################################################################

sub _parse_short {
	my $self	= shift;
	my $s		= shift;
	for ($s) {
		s/\\"/"/g;
		s/\\t/\t/g;
		s/\\r/\r/g;
		s/\\n/\n/g;
	}
	return '' unless length($s);
	return _unescape($s);
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
	return '' unless length($s);
	return _unescape($s);
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
	
	if ($datatype eq "${xsd}decimal") {
		$value	=~ s/[.]0+$//;
		if ($value !~ /[.]/) {
			$value = $value . '.0';
		}
	}
	return RDF::Trine::Node::Literal->new($value, undef, $datatype)
}

sub __anonimize_bnode_id {
	my $self	= shift;
	my $id		= shift;
	if (my $aid = $self->{ bnode_map }{ $id }) {
		return $aid;
	} else {
		my $aid	= $self->__generate_bnode_id;
		$self->{ bnode_map }{ $id }	= $aid;
		return $aid;
	}
}

sub __generate_bnode_id {
	my $self	= shift;
	my $id		= $self->{ bnode_id }++;
	return 'r' . $self->{bnode_prefix} . 'r' . $id;
}

sub __consume_ws {
	my $self	= shift;
	while ($self->{tokens} =~ m/^[\t\r\n #]/) {
		$self->_ws()
	}
}

sub __URI {
	my $self	= shift;
	my $uri		= shift;
	my $base	= shift;
	return RDF::Trine::Node::Resource->new( $uri, $base )
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

sub _unescape {
	my $str = shift;
	my @chars = split(//, $str);
	my $us	= '';
	while(defined(my $char = shift(@chars))) {
		if($char eq '\\') {
			if(($char = shift(@chars)) eq 'u') {
				my $i = 0;
				for(; $i < 4; $i++) {
					unless($chars[$i] =~ /[0-9a-fA-F]/){
						last;
					}				
				}
				if($i == 4) {
					my $hex = join('', splice(@chars, 0, 4));
					my $cp = hex($hex);
					my $char	= chr($cp);
					$us .= $char;
				}
				else {
					$us .= 'u';
				}
			}
			else {
				$us .= '\\' . $char;
			}
		}
		else {
			$us .= $char;
		}
	}
	return $us;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
