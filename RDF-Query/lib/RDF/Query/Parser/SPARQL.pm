# RDF::Query::Parser::SPARQL
# -------------
# $Revision: 127 $
# $Date: 2006-02-08 14:53:21 -0500 (Wed, 08 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::SPARQL - SPARQL Parser.

=head1 VERSION

This document describes RDF::Query::Parser::SPARQL version 1.000

=head1 SYNOPSIS

 use RDF::Query::Parser::SPARQL;
 my $parser	= RDF::Query::Parse::SPARQL->new();
 my $iterator = $parser->parse( $query, $base_uri );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Query::Parser::SPARQL;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Parser);
our $VERSION	= '1.000';

use URI;
use Data::Dumper;
use RDF::Query::Error qw(:try);
use RDF::Query::Parser;
use RDF::Query::Algebra;
use RDF::Trine::Namespace qw(rdf);
use Scalar::Util qw(blessed looks_like_number);
use List::MoreUtils qw(uniq);

# our $r_nil					= qr'[(][\n\r\t ]*[)]';
# our $r_iri					= qr'<([^<>"{}|^`\x92]*)>';
# our $r_variable				= qr'[$?]([_A-Za-z][._A-Za-z0-9]*)';
# our $r_boolean				= qr'(?:true|false)';
# our $r_comment				= qr'#[^\r\n]*';
# our $r_decimal				= qr'[+-]?([0-9]+\.[0-9]*|\.([0-9])+)';
# our $r_double				= qr'[+-]?([0-9]+\.[0-9]*[eE][+-]?[0-9]+|\.[0-9]+[eE][+-]?[0-9]+|[0-9]+[eE][+-]?[0-9]+)';
# our $r_integer				= qr'[+-]?[0-9]+';
# our $r_language				= qr'[a-z]+(-[a-z0-9]+)*';
# our $r_lcharacters			= qr'(?s)[^"\\]*(?:(?:\\.|"(?!""))[^"\\]*)*';
# our $r_line					= qr'([^\r\n]+[\r\n]+)(?=[^\r\n])';
# our $r_nameChar_extra		= qr'[-0-9\x{B7}\x{0300}-\x{036F}\x{203F}-\x{2040}]';
# our $r_nameStartChar		= qr'[A-Z_a-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]';
# our $r_nameStartChar_minus_underscore	= qr'[A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{00010000}-\x{000EFFFF}]';
# our $r_scharacters			= qr'[^"\\]*(?:\\.[^"\\]*)*';
# our $r_ucharacters			= qr'[^>\\]*(?:\\.[^>\\]*)*';
# our $r_booltest				= qr'(true|false)\b';
# our $r_resource_test		= qr/(?![_[("0-9+-]|$r_booltest)/;
# our $r_nameChar_test		= qr"(?:$r_nameStartChar|$r_nameChar_extra)";

our $r_ECHAR				= qr/\\([tbnrf\\"'])/;
our $r_STRING_LITERAL1		= qr/'(([^\x{27}\x{5C}\x{0A}\x{0D}])|${r_ECHAR})*'/;
our $r_STRING_LITERAL2		= qr/"(([^\x{22}\x{5C}\x{0A}\x{0D}])|${r_ECHAR})*"/;
our $r_STRING_LITERAL_LONG1	= qr/'''(('|'')?([^'\\]|${r_ECHAR}))*'''/;
our $r_STRING_LITERAL_LONG2	= qr/"""(("|"")?([^"\\]|${r_ECHAR}))*"""/;
our $r_LANGTAG				= qr/@[a-zA-Z]+(-[a-zA-Z0-9]+)*/;
our $r_IRI_REF				= qr/<([^<>"{}|^`\\\x{00}-\x{20}])*>/;
our $r_PN_CHARS_BASE		= qr/([A-Z]|[a-z]|[\x{00C0}-\x{00D6}]|[\x{00D8}-\x{00F6}]|[\x{00F8}-\x{02FF}]|[\x{0370}-\x{037D}]|[\x{037F}-\x{1FFF}]|[\x{200C}-\x{200D}]|[\x{2070}-\x{218F}]|[\x{2C00}-\x{2FEF}]|[\x{3001}-\x{D7FF}]|[\x{F900}-\x{FDCF}]|[\x{FDF0}-\x{FFFD}]|[\x{10000}-\x{EFFFF}])/;
our $r_PN_CHARS_U			= qr/(_|${r_PN_CHARS_BASE})/;
our $r_VARNAME				= qr/((${r_PN_CHARS_U}|[0-9])(${r_PN_CHARS_U}|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}])*)/;
our $r_VAR1					= qr/[?]${r_VARNAME}/;
our $r_VAR2					= qr/[\$]${r_VARNAME}/;
our $r_PN_CHARS				= qr/${r_PN_CHARS_U}|-|[0-9]|\x{00B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]/;
our $r_PN_PREFIX			= qr/(${r_PN_CHARS_BASE}((${r_PN_CHARS}|[.])*${r_PN_CHARS})?)/;
our $r_PN_LOCAL				= qr/((${r_PN_CHARS_U}|[0-9])((${r_PN_CHARS}|[.])*${r_PN_CHARS})?)/;
our $r_PNAME_NS				= qr/((${r_PN_PREFIX})?:)/;
our $r_PNAME_LN				= qr/(${r_PNAME_NS}${r_PN_LOCAL})/;
our $r_EXPONENT				= qr/[eE][-+]?\d+/;
our $r_DOUBLE				= qr/\d+[.]\d*${r_EXPONENT}|[.]\d+${r_EXPONENT}|\d+${r_EXPONENT}/;
our $r_DECIMAL				= qr/(\d+[.]\d*)|([.]\d+)/;
our $r_INTEGER				= qr/\d+/;
our $r_BLANK_NODE_LABEL		= qr/_:${r_PN_LOCAL}/;
our $r_ANON					= qr/\[[\t\r\n ]*\]/;
our $r_NIL					= qr/\([\n\r\t ]*\)/;

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

################################################################################

=item C<< parse ( $query, $base_uri ) >>

Parses the C<< $query >>, using the given C<< $base_uri >>.

=cut

sub parse {
	my $self	= shift;
	my $input	= shift;
	my $uri		= shift;
	
	$input		=~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/ge;
	$input		=~ s/\\U([0-9A-Fa-f]{8})/chr(hex($1))/ge;
	
	delete $self->{error};
	local($self->{namespaces})				= {};
	local($self->{blank_ids})				= 1;
	local($self->{baseURI})					= $uri;
	local($self->{tokens})					= $input;
	local($self->{stack})					= [];
	local($self->{filters})					= [];
	local($self->{pattern_container_stack})	= [];
	my $triples								= $self->_push_pattern_container();
	$self->{build}							= { sources => [], triples => $triples };
	
	try {
		$self->_Query();
	} catch RDF::Query::Error with {
		my $e	= shift;
		$self->{build}	= undef;
		$self->{error}	= $e->text;
	};
	my $data								= delete $self->{build};
#	$data->{triples}						= $self->_pop_pattern_container();
	return $data;
}

=item C<< error >>

Returns the error encountered during the last parse.

=cut

sub error {
	my $self	= shift;
	return $self->{error};
}

sub _add_patterns {
	my $self	= shift;
	my @triples	= @_;
	my $container	= $self->{ pattern_container_stack }[0];
	push( @{ $container }, @triples );
}

sub _remove_pattern {
	my $self	= shift;
	my $container	= $self->{ pattern_container_stack }[0];
	my $pattern		= pop( @{ $container } );
	return $pattern;
}

sub _peek_pattern {
	my $self	= shift;
	my $container	= $self->{ pattern_container_stack }[0];
	my $pattern		= $container->[-1];
	return $pattern;
}

sub _push_pattern_container {
	my $self	= shift;
	my $cont	= [];
	unshift( @{ $self->{ pattern_container_stack } }, $cont );
	return $cont;
}

sub _pop_pattern_container {
	my $self	= shift;
	my $cont	= shift( @{ $self->{ pattern_container_stack } } );
	return $cont;
}

sub _add_stack {
	my $self	= shift;
	my @items	= @_;
	push( @{ $self->{stack} }, @items );
}

sub _add_filter {
	my $self	= shift;
	my @filters	= shift;
	push( @{ $self->{filters} }, @filters );
}

sub _eat {
	my $self	= shift;
	my $thing	= shift;
	if (not(length($self->{tokens}))) {
		$self->_syntax_error("no tokens left");
	}
	
# 	if (substr($self->{tokens}, 0, 1) eq '^') {
# 		Carp::cluck( "eating $thing with input $self->{tokens}" );
# 	}
	
	if (blessed($thing) and $thing->isa('Regexp')) {
		if ($self->{tokens} =~ /^$thing/) {
			my $match	= $&;
			substr($self->{tokens}, 0, length($match))	= '';
			return $match;
		}
		
		$self->_syntax_error( $thing );
	} elsif (looks_like_number( $thing )) {
		my ($token)	= substr( $self->{tokens}, 0, $thing, '' );
		return $token
	} else {
		### thing is a string
		if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
			substr($self->{tokens}, 0, length($thing))	= '';
			return $thing;
		} else {
			$self->_syntax_error( $thing );
		}
	}
	print $thing;
	throw RDF::Query::Error;
}

sub _syntax_error {
	my $self	= shift;
	my $thing	= shift;
	my $expect	= $thing;

	my $level	= 2;
	while (my $sub = (caller($level++))[3]) {
		if ($sub =~ m/::_([A-Z]\w*)$/) {
			$expect	= $1;
			last;
		}
	}
	
	Carp::cluck( "eating $thing with input <<$self->{tokens}>>" ) if ($debug);
	throw RDF::Query::Error::ParseError -text => "Syntax error: Expected $expect";
}

sub _test {
	my $self	= shift;
	my $thing	= shift;
	if (blessed($thing) and $thing->isa('Regexp')) {
		if ($self->{tokens} =~ m/^$thing/) {
			return 1;
		} else {
			return 0;
		}
	} else {
		if (substr($self->{tokens}, 0, length($thing)) eq $thing) {
			return 1;
		} else {
			return 0;
		}
	}
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
		$self->_eat(qr/#[^\x0d\x0a]*.?/);
	} else {
		$self->_eat(qr/[\n\r\t ]/);
	}
}

sub __consume_ws_opt {
	my $self	= shift;
	if ($self->_ws_test) {
		$self->__consume_ws;
	}
}

sub __consume_ws {
	my $self	= shift;
	$self->_ws;
	while ($self->_ws_test()) {
		$self->_ws()
	}
}

sub __base {
	my $self	= shift;
	my $build	= $self->{build};
	if (defined($build->{base})) {
		return $build->{base};
	} else {
		return;
	}
}

################################################################################


# [1] Query ::= Prologue ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery )
sub _Query {
	my $self	= shift;
	$self->__consume_ws_opt;
	$self->_Prologue;
	$self->__consume_ws_opt;
	if ($self->_test(qr/SELECT/i)) {
		$self->_SelectQuery();
	} elsif ($self->_test(qr/CONSTRUCT/i)) {
		$self->_ConstructQuery();
	} elsif ($self->_test(qr/DESCRIBE/i)) {
		$self->_DescribeQuery();
	} elsif ($self->_test(qr/ASK/i)) {
		$self->_AskQuery();
	} else {
		throw RDF::Query::Error::ParseError -text => 'Syntax error: Expected query type';
	}
	
	my $remaining	= $self->{tokens};
	if ($remaining =~ m/\S/) {
		throw RDF::Query::Error::ParseError -text => "Remaining input after query: $remaining";
	}
	
# 	my %query	= (%p, %body);
# 	return \%query;
}


# [2] Prologue ::= BaseDecl? PrefixDecl*
# [3] BaseDecl ::= 'BASE' IRI_REF
# [4] PrefixDecl ::= 'PREFIX' PNAME_NS IRI_REF
sub _Prologue {
	my $self	= shift;
	
	my $base;
	my @base;
	if ($self->_test( qr/BASE/i )) {
		$self->_eat( qr/BASE/i );
		$self->__consume_ws_opt;
		my $iriref	= $self->_eat( $r_IRI_REF );
		my $iri		= substr($iriref,1,length($iriref)-2);
		$base		= RDF::Query::Node::Resource->new( $iri );
		@base		= $base;
		$self->__consume_ws_opt;
		$self->{base}	= $base;
	}
	
	my %namespaces;
	while ($self->_test( qr/PREFIX/i )) {
		$self->_eat( qr/PREFIX/i );
		$self->__consume_ws_opt;
		my $prefix	= $self->_eat( $r_PNAME_NS );
		my $ns		= substr($prefix, 0, length($prefix) - 1);
		if ($ns eq '') {
			$ns	= '__DEFAULT__';
		}
		$self->__consume_ws_opt;
		my $iriref	= $self->_eat( $r_IRI_REF );
		my $iri		= substr($iriref,1,length($iriref)-2);
		if (@base) {
			my $r	= RDF::Query::Node::Resource->new( $iri, @base );
			$iri	= $r->uri_value;
		}
		$self->__consume_ws_opt;
		$namespaces{ $ns }	= $iri;
		$self->{namespaces}{$ns}	= $iri;
	}
	
	$self->{build}{namespaces}	= \%namespaces;
	$self->{build}{base}		= $base if (defined($base));
	
# 	push(@data, (base => $base)) if (defined($base));
# 	return @data;
}


# [5] SelectQuery ::= 'SELECT' ( 'DISTINCT' | 'REDUCED' )? ( Var+ | '*' ) DatasetClause* WhereClause SolutionModifier
sub _SelectQuery {
	my $self	= shift;
	$self->_eat(qr/SELECT/i);
	$self->__consume_ws;
	
	if ($self->{tokens} =~ m/^(DISTINCT|REDUCED)/i) {
		my $mod	= $self->_eat( qr/DISTINCT|REDUCED/i );
		$self->__consume_ws;
		$self->{build}{options}{lc($mod)}	= 1;
	}
	
	my $star	= 0;
	if ($self->_test('*')) {
		$self->_eat('*');
		$star	= 1;
		$self->__consume_ws_opt;
	} else {
		$self->_Var;
		$self->__consume_ws_opt;
		while ($self->{tokens} =~ m'^[?$]') {
			$self->_Var;
			$self->__consume_ws_opt;
		}
		$self->{build}{variables}	= [ splice(@{ $self->{stack} }) ];
	}
	
	$self->_DatasetClause();
	
	$self->__consume_ws_opt;
	$self->_WhereClause;

	if ($star) {
		my $triples	= $self->{build}{triples} || [];
		my @vars	= uniq( map { $_->referenced_variables } @$triples );
		$self->{build}{variables}	= [ map { $self->new_variable($_) } @vars ];
	}
	
	$self->__consume_ws_opt;
	$self->_SolutionModifier();
# 	%mod		= (%mod, %somod);
	
	$self->{build}{method}		= 'SELECT';
# 	my %query	= (
# 		variables	=> $vars,
# 		method		=> 'SELECT',
# 		sources		=> \@dataset,
# 		triples		=> $where,
# 		%mod,
# 	);
# 	
# 	return %query;
}

# [6] ConstructQuery ::= 'CONSTRUCT' ConstructTemplate DatasetClause* WhereClause SolutionModifier
sub _ConstructQuery {
	my $self	= shift;
	$self->_eat(qr/CONSTRUCT/i);
	$self->__consume_ws_opt;
	$self->_ConstructTemplate;
	$self->__consume_ws_opt;
	$self->_DatasetClause();
	$self->__consume_ws_opt;
	$self->_WhereClause;
	$self->_SolutionModifier();
	$self->{build}{method}		= 'CONSTRUCT';
}

# [7] DescribeQuery ::= 'DESCRIBE' ( VarOrIRIref+ | '*' ) DatasetClause* WhereClause? SolutionModifier
sub _DescribeQuery {
	my $self	= shift;
	$self->_eat(qr/DESCRIBE/i);
	$self->_ws;
	
	if ($self->_test('*')) {
		$self->_eat('*');
		$self->{build}{variables}	= ['*'];
		$self->__consume_ws_opt;
	} else {
		$self->_VarOrIRIref;
		$self->__consume_ws_opt;
		while ($self->_VarOrIRIref_test) {
			$self->_VarOrIRIref;
			$self->__consume_ws_opt;
		}
		$self->{build}{variables}	= [ splice(@{ $self->{stack} }) ];
	}
	
	$self->_DatasetClause();
	
	$self->__consume_ws_opt;
	if ($self->_WhereClause_test) {
		$self->_WhereClause;
	}
	
	$self->_SolutionModifier();
	$self->{build}{method}		= 'DESCRIBE';
}

# [8] AskQuery ::= 'ASK' DatasetClause* WhereClause
sub _AskQuery {
	my $self	= shift;
	$self->_eat(qr/ASK/i);
	$self->_ws;
	
	$self->_DatasetClause();
	
	$self->__consume_ws_opt;
	$self->_WhereClause;
	
	$self->{build}{variables}	= [];
	$self->{build}{method}		= 'ASK';
}

# [9] DatasetClause ::= 'FROM' ( DefaultGraphClause | NamedGraphClause )
sub _DatasetClause {
	my $self	= shift;
	
# 	my @dataset;
 	$self->{build}{sources}	= [];
	while ($self->_test( qr/FROM/i )) {
		$self->_eat( qr/FROM/i );
		$self->__consume_ws;
		if ($self->_test( qr/NAMED/i )) {
			$self->_NamedGraphClause;
		} else {
			$self->_DefaultGraphClause;
		}
		$self->__consume_ws_opt;
	}
}

# [10] DefaultGraphClause ::= SourceSelector
sub _DefaultGraphClause {
	my $self	= shift;
	$self->_SourceSelector;
	my ($source)	= splice(@{ $self->{stack} });
	push( @{ $self->{build}{sources} }, [$source] );
}

# [11] NamedGraphClause ::= 'NAMED' SourceSelector
sub _NamedGraphClause {
	my $self	= shift;
	$self->_eat( qr/NAMED/i );
	$self->__consume_ws_opt;
	$self->_SourceSelector;
	my ($source)	= splice(@{ $self->{stack} });
	push( @{ $self->{build}{sources} }, [$source, 'NAMED'] );
}

# [12] SourceSelector ::= IRIref
sub _SourceSelector {
	my $self	= shift;
	$self->_IRIref;
}

# [13] WhereClause ::= 'WHERE'? GroupGraphPattern
sub _WhereClause_test {
	my $self	= shift;
	return $self->_test( qr/WHERE|{/i );
}
sub _WhereClause {
	my $self	= shift;
	if ($self->_test( qr/WHERE/i )) {
		$self->_eat( qr/WHERE/i );
	}
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	
	my $ggp	= $self->_peek_pattern;
	$ggp->check_duplicate_blanks;
}

# [14] SolutionModifier ::= OrderClause? LimitOffsetClauses?
sub _SolutionModifier {
	my $self	= shift;
	
	if ($self->_OrderClause_test) {
		$self->_OrderClause;
		$self->__consume_ws_opt;
	}
	
	if ($self->_LimitOffsetClauses_test) {
		$self->_LimitOffsetClauses;
	}
}

# [15] LimitOffsetClauses ::= ( LimitClause OffsetClause? | OffsetClause LimitClause? )
sub _LimitOffsetClauses_test {
	my $self	= shift;
	return $self->_test( qr/LIMIT|OFFSET/i );
}

sub _LimitOffsetClauses {
	my $self	= shift;
	if ($self->_LimitClause_test) {
		$self->_LimitClause;
		$self->__consume_ws;
		if ($self->_OffsetClause_test) {
			$self->_OffsetClause;
		}
	} else {
		$self->_OffsetClause;
		$self->__consume_ws;
		if ($self->_LimitClause_test) {
			$self->_LimitClause;
		}
	}
}

# [16] OrderClause ::= 'ORDER' 'BY' OrderCondition+
sub _OrderClause_test {
	my $self	= shift;
	return $self->_test( qr/ORDER[\n\r\t ]+BY/i );
}

sub _OrderClause {
	my $self	= shift;
	$self->_eat( qr/ORDER/i );
	$self->__consume_ws;
	$self->_eat( qr/BY/i );
	$self->__consume_ws_opt;
	my @order;
	$self->_OrderCondition;
	$self->__consume_ws_opt;
	push(@order, splice(@{ $self->{stack} }));
	while ($self->_OrderCondition_test) {
		$self->_OrderCondition;
		$self->__consume_ws_opt;
		push(@order, splice(@{ $self->{stack} }));
	}
	$self->{build}{options}{orderby}	= \@order;
}

# [17] OrderCondition ::= ( ( 'ASC' | 'DESC' ) BrackettedExpression ) | ( Constraint | Var )
sub _OrderCondition_test {
	my $self	= shift;
	return 1 if $self->_test( qr/ASC|DESC|[?\$]/i );
	return 1 if $self->_Constraint_test;
	return 0;
}

sub _OrderCondition {
	my $self	= shift;
	my $dir	= 'ASC';
	if ($self->_test( qr/ASC|DESC/i )) {
		$dir	= uc( $self->_eat( qr/ASC|DESC/i ) );
		$self->__consume_ws_opt;
		$self->_BrackettedExpression;
	} elsif ($self->_test( qr/[?\$]/ )) {
		$self->_Var;
	} else {
		$self->_Constraint;
	}
	my ($expr)	= splice(@{ $self->{stack} });
	$self->_add_stack( [ $dir, $expr ] );
}

# [18] LimitClause ::= 'LIMIT' INTEGER
sub _LimitClause_test {
	my $self	= shift;
	return $self->_test( qr/LIMIT/i );
}

sub _LimitClause {
	my $self	= shift;
	$self->_eat( qr/LIMIT/i );
	$self->__consume_ws;
	my $limit	= $self->_eat( $r_INTEGER );
	$self->{build}{options}{limit}	= $limit;
}

# [19] OffsetClause ::= 'OFFSET' INTEGER
sub _OffsetClause_test {
	my $self	= shift;
	return $self->_test( qr/OFFSET/i );
}

sub _OffsetClause {
	my $self	= shift;
	$self->_eat( qr/OFFSET/i );
	$self->__consume_ws;
	my $off	= $self->_eat( $r_INTEGER );
	$self->{build}{options}{offset}	= $off;
}

# [20] GroupGraphPattern ::= '{' TriplesBlock? ( ( GraphPatternNotTriples | Filter ) '.'? TriplesBlock? )* '}'
sub _GroupGraphPattern {
	my $self	= shift;
	$self->_push_pattern_container;
	
	$self->_eat('{');
	$self->__consume_ws_opt;
	
	my $got_pattern	= 0;
	my $need_dot	= 0;
	if ($self->_TriplesBlock_test) {
		$need_dot	= 1;
		$got_pattern++;
		$self->_TriplesBlock;
		$self->__consume_ws_opt;
	}
	
	my $pos	= length($self->{tokens});
	while (not $self->_test('}')) {
		if ($self->_GraphPatternNotTriples_test) {
			$need_dot	= 0;
			$got_pattern++;
			$self->_GraphPatternNotTriples;
			$self->__consume_ws_opt;
			my ($data)	= splice(@{ $self->{stack} });
			my ($class, @args)	= @$data;
			if ($class eq 'RDF::Query::Algebra::Optional') {
				my $ggp	= $self->_remove_pattern();
				unless ($ggp) {
					$ggp	= RDF::Query::Algebra::GroupGraphPattern->new();
				}
				my $opt	= $class->new( $ggp, @args );
				$self->_add_patterns( $opt );
			} elsif ($class eq 'RDF::Query::Algebra::Union') {
				# no-op
			} elsif ($class eq 'RDF::Query::Algebra::NamedGraph') {
				# no-op
			} elsif ($class eq 'RDF::Query::Algebra::GroupGraphPattern') {
				# no-op
			} else {
				Carp::confess Dumper($class, \@args);
			}
			$self->__consume_ws_opt;
		} elsif ($self->_test( qr/FILTER/i )) {
			$got_pattern++;
			$need_dot	= 0;
			$self->_Filter;
			$self->__consume_ws_opt;
		}
		
		if ($need_dot or $self->_test('.')) {
			$self->_eat('.');
			if ($got_pattern) {
				$need_dot		= 0;
				$got_pattern	= 0;
			} else {
				throw RDF::Query::Error::ParseError -text => "Syntax error: Extra dot found without preceding pattern";
			}
			$self->__consume_ws_opt;
		}
		
		if ($self->_TriplesBlock_test) {
			my $peek	= $self->_peek_pattern;
			if (blessed($peek) and $peek->isa('RDF::Query::Algebra::BasicGraphPattern')) {
				$self->_TriplesBlock;
				my $rhs		= $self->_remove_pattern;
				my $lhs		= $self->_remove_pattern;
				my $merged	= RDF::Query::Algebra::BasicGraphPattern->new( map { $_->triples } ($lhs, $rhs) );
				$self->_add_patterns( $merged );
			} else {
				$self->_TriplesBlock;
			}
			$self->__consume_ws_opt;
		}
		
		$self->__consume_ws_opt;
		last unless ($self->_test( qr/\S/ ));
		
		my $new	= length($self->{tokens});
		if ($pos == $new) {
			# we haven't progressed, and so would infinite loop if we don't break out and throw an error.
			$self->_syntax_error('');
		} else {
			$pos	= $new;
		}
	}
	
	$self->_eat('}');

	my $cont		= $self->_pop_pattern_container;
	
	my @filters		= splice(@{ $self->{filters} });
	my @patterns;
	my $pattern	= RDF::Query::Algebra::GroupGraphPattern->new( @$cont );
	while (my $f = shift @filters) {
		$pattern	= RDF::Query::Algebra::Filter->new( $f->expr, $pattern );
	}
	$self->_add_patterns( $pattern );
}

# [21] TriplesBlock ::= TriplesSameSubject ( '.' TriplesBlock? )?
sub _TriplesBlock_test {
	my $self	= shift;
	# VarOrTerm | TriplesNode -> (Var | GraphTerm) | (Collection | BlankNodePropertyList) -> Var | IRIref | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | NIL | Collection | BlankNodePropertyList
	# but since a triple can't start with a literal, this is reduced to:
	# Var | IRIref | BlankNode | NIL
	return $self->_test(qr/[\$?]|<|_:|\[[\n\r\t ]*\]|\([\n\r\t ]*\)|\[|[[(]|${r_PNAME_NS}/);
}

sub _TriplesBlock {
	my $self	= shift;
	$self->_push_pattern_container;
	$self->__TriplesBlock;
	my $triples		= $self->_pop_pattern_container;
	my $bgp			= RDF::Query::Algebra::BasicGraphPattern->new( @$triples );
	$self->_add_patterns( $bgp );
}

## this one (with two underscores) doesn't pop patterns off the stack and make a BGP.
## instead, things are left on the stack so we can recurse without doing the wrong thing.
## the one with one underscore (_TriplesBlock) will pop everything off and make the BGP.
sub __TriplesBlock {
	my $self	= shift;
	$self->_TriplesSameSubject;
	$self->__consume_ws_opt;
	my $got_dot	= 0;
	while ($self->_test('.')) {
		if ($got_dot) {
			throw RDF::Query::Error::ParseError -text => "Syntax error: found extra DOT after TriplesBlock";
		}
		$self->_eat('.');
		$got_dot++;
		$self->__consume_ws_opt;
		if ($self->_TriplesBlock_test) {
			$got_dot	= 0;
			$self->__TriplesBlock;
			$self->__consume_ws_opt;
		}
	}
}

# [22] GraphPatternNotTriples ::= OptionalGraphPattern | GroupOrUnionGraphPattern | GraphGraphPattern
sub _GraphPatternNotTriples_test {
	my $self	= shift;
	return $self->_test(qr/OPTIONAL|{|GRAPH/);
}

sub _GraphPatternNotTriples {
	my $self	= shift;
	if ($self->_OptionalGraphPattern_test) {
		$self->_OptionalGraphPattern;
	} elsif ($self->_GroupOrUnionGraphPattern_test) {
		$self->_GroupOrUnionGraphPattern;
	} else {
		$self->_GraphGraphPattern;
	}
}

# [23] OptionalGraphPattern ::= 'OPTIONAL' GroupGraphPattern
sub _OptionalGraphPattern_test {
	my $self	= shift;
	return $self->_test( qr/OPTIONAL/i );
}

sub _OptionalGraphPattern {
	my $self	= shift;
	$self->_eat( qr/OPTIONAL/i );
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	my $opt		= ['RDF::Query::Algebra::Optional', $ggp];
	$self->_add_stack( $opt );
}

# [24] GraphGraphPattern ::= 'GRAPH' VarOrIRIref GroupGraphPattern
sub _GraphGraphPattern {
	my $self	= shift;
	$self->_eat( qr/GRAPH/i );
	$self->__consume_ws;
	$self->_VarOrIRIref;
	my ($graph)	= splice(@{ $self->{stack} });
	
	$self->__consume_ws_opt;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	
	my $pattern	= RDF::Query::Algebra::NamedGraph->new( $graph, $ggp );
	$self->_add_patterns( $pattern );
	$self->_add_stack( [ 'RDF::Query::Algebra::NamedGraph' ] );
}

# [25] GroupOrUnionGraphPattern ::= GroupGraphPattern ( 'UNION' GroupGraphPattern )*
sub _GroupOrUnionGraphPattern_test {
	my $self	= shift;
	return $self->_test('{');
}

sub _GroupOrUnionGraphPattern {
	my $self	= shift;
	$self->_GroupGraphPattern;
	my $ggp	= $self->_remove_pattern;
	$self->__consume_ws_opt;
	
	if ($self->_test( qr/UNION/i )) {
		while ($self->_test( qr/UNION/i )) {
			$self->_eat( qr/UNION/i );
			$self->__consume_ws_opt;
			$self->_GroupGraphPattern;
			$self->__consume_ws_opt;
			my $rhs	= $self->_remove_pattern;
			$ggp	= RDF::Query::Algebra::Union->new( $ggp, $rhs );
		}
		$self->_add_patterns( $ggp );
		$self->_add_stack( [ 'RDF::Query::Algebra::Union' ] );
	} else {
		$self->_add_patterns( $ggp );
		$self->_add_stack( [ 'RDF::Query::Algebra::GroupGraphPattern' ] );
	}
}

# [26] Filter ::= 'FILTER' Constraint
sub _Filter {
	my $self	= shift;
	$self->_eat( qr/FILTER/i );
	$self->__consume_ws_opt;
	$self->_Constraint;
	my ($expr) = splice(@{ $self->{stack} });
	$self->_add_filter( $self->new_filter( $expr ) );
}

# [27] Constraint ::= BrackettedExpression | BuiltInCall | FunctionCall
sub _Constraint_test {
	my $self	= shift;
	return 1 if $self->_test( qr/[(]/ );
	return 1 if $self->_BuiltInCall_test;
	return 1 if $self->_FunctionCall_test;
	return 0;
}

sub _Constraint {
	my $self	= shift;
	if ($self->_BrackettedExpression_test) {
		$self->_BrackettedExpression();
	} elsif ($self->_BuiltInCall_test) {
		$self->_BuiltInCall();
	} else {
		$self->_FunctionCall();
	}
}

# [28] FunctionCall ::= IRIref ArgList
sub _FunctionCall_test {
	my $self	= shift;
	return $self->_IRIref_test;
}

sub _FunctionCall {
	my $self	= shift;
	$self->_IRIref;
	my ($iri)	= splice(@{ $self->{stack} });
	
	$self->__consume_ws_opt;
	
	$self->_ArgList;
	my @args	= splice(@{ $self->{stack} });
	my $func	= $self->new_function_expression( $iri, @args );
	$self->_add_stack( $func );
}

# [29] ArgList ::= ( NIL | '(' Expression ( ',' Expression )* ')' )
sub _ArgList_test {
	my $self	= shift;
	return $self->_test('(');
}

sub _ArgList {
	my $self	= shift;
	$self->_eat('(');
	$self->__consume_ws_opt;
	my @args;
	unless ($self->_test(')')) {
		$self->_Expression;
		push( @args, splice(@{ $self->{stack} }) );
		while ($self->_test(',')) {
			$self->_eat(',');
			$self->__consume_ws_opt;
			$self->_Expression;
			push( @args, splice(@{ $self->{stack} }) );
		}
	}
	$self->_eat(')');
	$self->_add_stack( @args );
}

# [30] ConstructTemplate ::= '{' ConstructTriples? '}'
sub _ConstructTemplate {
	my $self	= shift;
	$self->_push_pattern_container;
	$self->_eat( '{' );
	$self->__consume_ws_opt;
	
	if ($self->_ConstructTriples_test) {
		$self->_ConstructTriples;
	}

	$self->__consume_ws_opt;
	$self->_eat( '}' );
	my $cont	= $self->_pop_pattern_container;
	$self->{build}{construct_triples}	= $cont;
}

# [31] ConstructTriples ::= TriplesSameSubject ( '.' ConstructTriples? )?
sub _ConstructTriples_test {
	my $self	= shift;
	return $self->_TriplesBlock_test;
}

sub _ConstructTriples {
	my $self	= shift;
	$self->_TriplesSameSubject;
	$self->__consume_ws_opt;
	while ($self->_test(qr/[.]/)) {
		$self->_eat( qr/[.]/ );
		$self->__consume_ws_opt;
		if ($self->_ConstructTriples_test) {
			$self->_TriplesSameSubject;
		}
	}
}

# [32] TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | TriplesNode PropertyList
sub _TriplesSameSubject {
	my $self	= shift;
	my @triples;
	if ($self->_TriplesNode_test) {
		$self->_TriplesNode;
		my ($s)	= splice(@{ $self->{stack} });
		$self->__consume_ws_opt;
		$self->_PropertyList;
		$self->__consume_ws_opt;
		
		my @list	= splice(@{ $self->{stack} });
		foreach my $data (@list) {
			push(@triples, RDF::Query::Algebra::Triple->new( $s, @$data ));
		}
	} else {
		$self->_VarOrTerm;
		my ($s)	= splice(@{ $self->{stack} });

		$self->__consume_ws_opt;
		$self->_PropertyListNotEmpty;
		$self->__consume_ws_opt;
		my (@list)	= splice(@{ $self->{stack} });
		foreach my $data (@list) {
			push(@triples, RDF::Query::Algebra::Triple->new( $s, @$data ));
		}
	}
	
	$self->_add_patterns( @triples );
#	return @triples;
}

# [33] PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*
sub _PropertyListNotEmpty {
	my $self	= shift;
	$self->_Verb;
	my ($v)	= splice(@{ $self->{stack} });
	$self->__consume_ws_opt;
	$self->_ObjectList;
	my @l	= splice(@{ $self->{stack} });
	my @props		= map { [$v, $_] } @l;
	while ($self->_test(qr'\s*;')) {
		$self->_eat(';');
		$self->__consume_ws_opt;
		if ($self->_Verb_test) {
			$self->_Verb;
			my ($v)	= splice(@{ $self->{stack} });
			$self->__consume_ws_opt;
			$self->_ObjectList;
			my @l	= splice(@{ $self->{stack} });
			push(@props, map { [$v, $_] } @l);
		}
	}
	$self->_add_stack( @props );
}

# [34] PropertyList ::= PropertyListNotEmpty?
sub _PropertyList {
	my $self	= shift;
	if ($self->_Verb_test) {
		$self->_PropertyListNotEmpty;
	}
}

# [35] ObjectList ::= Object ( ',' Object )*
sub _ObjectList {
	my $self	= shift;
	
	my @list;
	$self->_Object;
	push(@list, splice(@{ $self->{stack} }));
	
	$self->__consume_ws_opt;
	while ($self->_test(',')) {
		$self->_eat(',');
		$self->__consume_ws_opt;
		$self->_Object;
		push(@list, splice(@{ $self->{stack} }));
		$self->__consume_ws_opt;
	}
	$self->_add_stack( @list );
}

# [36] Object ::= GraphNode
sub _Object {
	my $self	= shift;
	$self->_GraphNode;
}

# [37] Verb ::= VarOrIRIref | 'a'
sub _Verb_test {
	my $self	= shift;
	return $self->_test( qr/a[\n\t\r <]|[?\$]|<|${r_PNAME_LN}|${r_PNAME_NS}/ );
}

sub _Verb {
	my $self	= shift;
	if ($self->_test(qr/a[\n\t\r <]/)) {
		$self->_eat('a');
		$self->__consume_ws;
		my $type	= RDF::Query::Node::Resource->new( $rdf->type->uri_value );
		$self->_add_stack( $type );
	} else {
		$self->_VarOrIRIref;
	}
}

# [38] TriplesNode ::= Collection | BlankNodePropertyList
sub _TriplesNode_test {
	my $self	= shift;
	return $self->_test(qr/[[(](?![\n\r\t ]*\])(?![\n\r\t ]*\))/);
}

sub _TriplesNode {
	my $self	= shift;
	if ($self->_test(qr/\(/)) {
		$self->_Collection;
	} else {
		$self->_BlankNodePropertyList;
	}
}

# [39] BlankNodePropertyList ::= '[' PropertyListNotEmpty ']'
sub _BlankNodePropertyList {
	my $self	= shift;
	$self->_eat('[');
	$self->__consume_ws_opt;
	$self->_PropertyListNotEmpty;	
	$self->__consume_ws_opt;
	$self->_eat(']');
	
	my @props	= splice(@{ $self->{stack} });
	my $subj	= $self->new_blank;
	my @triples	= map { RDF::Query::Algebra::Triple->new( $subj, @$_ ) } @props;
	$self->_add_patterns( @triples );
	$self->_add_stack( $subj );
}

# [40] Collection ::= '(' GraphNode+ ')'
sub _Collection {
	my $self	= shift;
	$self->_eat('(');
	$self->__consume_ws_opt;
	$self->_GraphNode;
	$self->__consume_ws_opt;
	
	my @nodes;
	push(@nodes, splice(@{ $self->{stack} }));
	
	while ($self->_GraphNode_test) {
		$self->_GraphNode;
		$self->__consume_ws_opt;
		push(@nodes, splice(@{ $self->{stack} }));
	}
	
	$self->_eat(')');
	
	my $subj	= $self->new_blank;
	my $cur		= $subj;
	my $last;

	my $first	= RDF::Query::Node::Resource->new( $rdf->first->uri_value );
	my $rest	= RDF::Query::Node::Resource->new( $rdf->rest->uri_value );
	my $nil		= RDF::Query::Node::Resource->new( $rdf->nil->uri_value );

	
	my @triples;
	foreach my $node (@nodes) {
		push(@triples, RDF::Query::Algebra::Triple->new( $cur, $first, $node ) );
		my $new	= $self->new_blank;
		push(@triples, RDF::Query::Algebra::Triple->new( $cur, $rest, $new ) );
		$last	= $cur;
		$cur	= $new;
	}
	pop(@triples);
	push(@triples, RDF::Query::Algebra::Triple->new( $last, $rest, $nil ));
	$self->_add_patterns( @triples );
	
	$self->_add_stack( $subj );
}

# [41] GraphNode ::= VarOrTerm | TriplesNode
sub _GraphNode_test {
	my $self	= shift;
	# VarOrTerm | TriplesNode -> (Var | GraphTerm) | (Collection | BlankNodePropertyList) -> Var | IRIref | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | NIL | Collection | BlankNodePropertyList
	# but since a triple can't start with a literal, this is reduced to:
	# Var | IRIref | BlankNode | NIL
	return $self->_test(qr/[\$?]|<|['"]|(true\b|false\b)|([+-]?\d)|_:|${r_ANON}|${r_NIL}|\[|[[(]/);
}

sub _GraphNode {
	my $self	= shift;
	if ($self->_TriplesNode_test) {
		$self->_TriplesNode;
	} else {
		$self->_VarOrTerm;
	}
}

# [42] VarOrTerm ::= Var | GraphTerm
sub _VarOrTerm_test {
	my $self	= shift;
	return 1 if ($self->_test(qr/[$?]/));
	return 1 if ($self->_test(qr/[<'".0-9]|(true|false)\b|_:|\([\n\r\t ]*\)/));
	return 0;
}

sub _VarOrTerm {
	my $self	= shift;
	if ($self->{tokens} =~ m'^[?$]') {
		$self->_Var;
	} else {
		$self->_GraphTerm;
	}
}

# [43] VarOrIRIref ::= Var | IRIref
sub _VarOrIRIref_test {
	my $self	= shift;
	return $self->_test(qr/[\$?]|<|${r_PNAME_LN}|${r_PNAME_NS}/);
}

sub _VarOrIRIref {
	my $self	= shift;
	if ($self->{tokens} =~ m'^[?$]') {
		$self->_Var;
	} else {
		$self->_IRIref;
	}
}

# [44] Var ::= VAR1 | VAR2
sub _Var {
	my $self	= shift;
	my $var		= ($self->_test( $r_VAR1 )) ? $self->_eat( $r_VAR1 ) : $self->_eat( $r_VAR2 );
	$self->_add_stack( RDF::Query::Node::Variable->new( substr($var,1) ) );
}

# [45] GraphTerm ::= IRIref | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | NIL
sub _GraphTerm {
	my $self	= shift;
	if ($self->_test(qr/(true|false)\b/)) {
		$self->_BooleanLiteral;
	} elsif ($self->_test('(')) {
		$self->_NIL;
	} elsif ($self->_test( $r_ANON ) or $self->_test('_:')) {
		$self->_BlankNode;
	} elsif ($self->_test(qr/[-+]?\d/)) {
		$self->_NumericLiteral;
	} elsif ($self->_test(qr/['"]/)) {
		$self->_RDFLiteral;
	} else {
		$self->_IRIref;
	}
}

# [46] Expression ::= ConditionalOrExpression
sub _Expression {
	my $self	= shift;
	$self->_ConditionalOrExpression;
}

# [47] ConditionalOrExpression ::= ConditionalAndExpression ( '||' ConditionalAndExpression )*
sub _ConditionalOrExpression {
	my $self	= shift;
	my @list;
	
	$self->_ConditionalAndExpression;
	push(@list, splice(@{ $self->{stack} }));
	
	$self->__consume_ws_opt;
	while ($self->_test('||')) {
		$self->_eat('||');
		$self->__consume_ws_opt;
		$self->_ConditionalAndExpression;
		push(@list, splice(@{ $self->{stack} }));
	}
	
	if (scalar(@list) > 1) {
		$self->_add_stack( $self->new_nary_expression( '||', @list ) );
	} else {
		$self->_add_stack( @list );
	}
	Carp::confess $self->{tokens} if (scalar(@{ $self->{stack} }) == 0);
}

# [48] ConditionalAndExpression ::= ValueLogical ( '&&' ValueLogical )*
sub _ConditionalAndExpression {
	my $self	= shift;
	my @list;
	
	$self->_ValueLogical;
	push(@list, splice(@{ $self->{stack} }));
	Carp::confess Dumper(\@list) if (scalar(@list) > 1);
	
	$self->__consume_ws_opt;
	while ($self->_test('&&')) {
		$self->_eat('&&');
		$self->__consume_ws_opt;
		$self->_ValueLogical;
		push(@list, splice(@{ $self->{stack} }));
	}
	
	if (scalar(@list) > 1) {
		$self->_add_stack( $self->new_nary_expression( '&&', @list ) );
	} else {
		$self->_add_stack( @list );
	}
}

# [49] ValueLogical ::= RelationalExpression
sub _ValueLogical {
	my $self	= shift;
	$self->_RelationalExpression;
}

# [50] RelationalExpression ::= NumericExpression ( '=' NumericExpression | '!=' NumericExpression | '<' NumericExpression | '>' NumericExpression | '<=' NumericExpression | '>=' NumericExpression )?
sub _RelationalExpression {
	my $self	= shift;
	$self->_NumericExpression;
	
	$self->__consume_ws_opt;
	if ($self->_test(qr/[!<>]?=|[<>]/)) {
		my @list	= splice(@{ $self->{stack} });
		my $op	= $self->_eat(qr/[!<>]?=|[<>]/);
		$op		= '==' if ($op eq '=');
		$self->__consume_ws_opt;
		$self->_NumericExpression;
		push(@list, splice(@{ $self->{stack} }));
		$self->_add_stack( $self->new_binary_expression( $op, @list ) );
	}
}

# [51] NumericExpression ::= AdditiveExpression
sub _NumericExpression {
	my $self	= shift;
	$self->_AdditiveExpression;
}

# [52] AdditiveExpression ::= MultiplicativeExpression ( '+' MultiplicativeExpression | '-' MultiplicativeExpression | NumericLiteralPositive | NumericLiteralNegative )*
sub _AdditiveExpression {
	my $self	= shift;
	$self->_MultiplicativeExpression;
	my ($expr)	= splice(@{ $self->{stack} });
	
	$self->__consume_ws_opt;
	while ($self->_test(qr/[-+]/)) {
		my $op	= $self->_eat(qr/[-+]/);
		$self->__consume_ws_opt;
		$self->_MultiplicativeExpression;
		my ($rhs)	= splice(@{ $self->{stack} });
		$expr	= $self->new_binary_expression( $op, $expr, $rhs );
	}
	$self->_add_stack( $expr );
}

# [53] MultiplicativeExpression ::= UnaryExpression ( '*' UnaryExpression | '/' UnaryExpression )*
sub _MultiplicativeExpression {
	my $self	= shift;
	$self->_UnaryExpression;
	my ($expr)	= splice(@{ $self->{stack} });
	
	$self->__consume_ws_opt;
	while ($self->_test(qr#[*/]#)) {
		my $op	= $self->_eat(qr#[*/]#);
		$self->__consume_ws_opt;
		$self->_UnaryExpression;
		my ($rhs)	= splice(@{ $self->{stack} });
		$expr	= $self->new_binary_expression( $op, $expr, $rhs );
	}
	$self->_add_stack( $expr );
}

# [54] UnaryExpression ::= '!' PrimaryExpression  | '+' PrimaryExpression  | '-' PrimaryExpression  | PrimaryExpression
sub _UnaryExpression {
	my $self	= shift;
	if ($self->_test('!')) {
		$self->_eat('!');
		$self->__consume_ws_opt;
		$self->_PrimaryExpression;
		my ($expr)	= splice(@{ $self->{stack} });
		my $not		= $self->new_unary_expression( '!', $expr );
		$self->_add_stack( $not );
	} elsif ($self->_test('+')) {
		$self->_eat('+');
		$self->__consume_ws_opt;
		$self->_PrimaryExpression;
	} elsif ($self->_test('-')) {
		$self->_eat('-');
		$self->__consume_ws_opt;
		$self->_PrimaryExpression;
		my ($expr)	= splice(@{ $self->{stack} });
		
		### if it's just a literal, force the negative down into the literal instead of make an unnecessary multiplication.
		if (blessed($expr) and $expr->isa('RDF::Trine::Node::Literal') and $expr->has_datatype and $expr->literal_datatype =~ m<^http://www.w3.org/2001/XMLSchema#(integer|decimal|double)>) {
			my $value	= -1 * $expr->literal_value;
			$expr->literal_value( $value );
			$self->_add_stack( $expr );
		} else {
			my $int		= RDF::Query::Node::Resource->new( $xsd->integer->uri_value );
			my $neg		= $self->new_binary_expression( '*', $self->new_literal('-1', undef, $int), $expr );
			$self->_add_stack( $neg );
		}
	} else {
		$self->_PrimaryExpression;
	}
}

# [55] PrimaryExpression ::= BrackettedExpression | BuiltInCall | IRIrefOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | Var
sub _PrimaryExpression {
	my $self	= shift;
	if ($self->_BrackettedExpression_test) {
		$self->_BrackettedExpression;
	} elsif ($self->_BuiltInCall_test) {
		$self->_BuiltInCall;
	} elsif ($self->_IRIref_test) {
		$self->_IRIrefOrFunction;
	} elsif ($self->_test(qr/[\$?]/)) {
		$self->_Var;
	} elsif ($self->_test(qr/(true|false)\b/)) {
		$self->_BooleanLiteral;
	} elsif ($self->_test(qr/[-+]?\d/)) {
		$self->_NumericLiteral;
	} else {	# if ($self->_test(qr/['"]/)) {
		$self->_RDFLiteral;
	}
}

# [56] BrackettedExpression ::= '(' Expression ')'
sub _BrackettedExpression_test {
	my $self	= shift;
	return $self->_test('(');
}

sub _BrackettedExpression {
	my $self	= shift;
	$self->_eat('(');
	$self->__consume_ws_opt;
	$self->_Expression;
	$self->__consume_ws_opt;
	$self->_eat(')');
}

# [57] BuiltInCall ::= 'STR' '(' Expression ')'  | 'LANG' '(' Expression ')'  | 'LANGMATCHES' '(' Expression ',' Expression ')'  | 'DATATYPE' '(' Expression ')'  | 'BOUND' '(' Var ')'  | 'sameTerm' '(' Expression ',' Expression ')'  | 'isIRI' '(' Expression ')'  | 'isURI' '(' Expression ')'  | 'isBLANK' '(' Expression ')'  | 'isLITERAL' '(' Expression ')'  | RegexExpression
sub _BuiltInCall_test {
	my $self	= shift;
	return $self->_test(qr/STR|LANG|LANGMATCHES|DATATYPE|BOUND|sameTerm|isIRI|isURI|isBLANK|isLITERAL|REGEX/i);
}

sub _BuiltInCall {
	my $self	= shift;
	if ($self->_RegexExpression_test) {
		$self->_RegexExpression;
	} else {
		my $op		= $self->_eat( qr/\w+/ );
		my $iri		= RDF::Query::Node::Resource->new( 'sparql:' . lc($op) );
		$self->__consume_ws_opt;
		$self->_eat('(');
		if ($op =~ /^(STR|LANG|DATATYPE|isIRI|isURI|isBLANK|isLITERAL)$/) {
			### one-arg functions that take an expression
			$self->_Expression;
			my ($expr)	= splice(@{ $self->{stack} });
			$self->_add_stack( RDF::Query::Algebra::Function->new($iri, $expr) );
		} elsif ($op =~ /^(LANGMATCHES|sameTerm)$/) {
			### two-arg functions that take expressions
			$self->_Expression;
			my ($arg1)	= splice(@{ $self->{stack} });
			$self->__consume_ws_opt;
			$self->_eat(',');
			$self->__consume_ws_opt;
			$self->_Expression;
			my ($arg2)	= splice(@{ $self->{stack} });
			$self->_add_stack( RDF::Query::Algebra::Function->new($iri, $arg1, $arg2) );
		} else {
			### BOUND(Var)
			$self->_Var;
			my ($expr)	= splice(@{ $self->{stack} });
			$self->_add_stack( RDF::Query::Algebra::Function->new($iri, $expr) );
		}
		$self->__consume_ws_opt;
		$self->_eat(')');
	}
}

# [58] RegexExpression ::= 'REGEX' '(' Expression ',' Expression ( ',' Expression )? ')'
sub _RegexExpression_test {
	my $self	= shift;
	return $self->_test( qr/REGEX/i );
}

sub _RegexExpression {
	my $self	= shift;
	$self->_eat( qr/REGEX/i );
	$self->__consume_ws_opt;
	$self->_eat('(');
	$self->__consume_ws_opt;
	$self->_Expression;
	my $string	= splice(@{ $self->{stack} });
	
	$self->__consume_ws_opt;
	$self->_eat(',');
	$self->__consume_ws_opt;
	$self->_Expression;
	my $pattern	= splice(@{ $self->{stack} });
	
	my @args	= ($string, $pattern);
	if ($self->_test(',')) {
		$self->_eat(',');
		$self->__consume_ws_opt;
		$self->_Expression;
		push(@args, splice(@{ $self->{stack} }));
	}
	
	$self->__consume_ws_opt;
	$self->_eat(')');
	
	my $iri		= RDF::Query::Node::Resource->new( 'sparql:regex' );
	$self->_add_stack( RDF::Query::Algebra::Function->new( $iri, @args ) );
}

# [59] IRIrefOrFunction ::= IRIref ArgList?
sub _IRIrefOrFunction_test {
	my $self	= shift;
	$self->_IRIref_test;
}

sub _IRIrefOrFunction {
	my $self	= shift;
	$self->_IRIref;
	if ($self->_ArgList_test) {
		my ($iri)	= splice(@{ $self->{stack} });
		$self->_ArgList;
		my @args	= splice(@{ $self->{stack} });
		my $func	= RDF::Query::Algebra::Function->new( $iri, @args );
		$self->_add_stack( $func );
	}
}

# [60] RDFLiteral ::= String ( LANGTAG | ( '^^' IRIref ) )?
sub _RDFLiteral {
	my $self	= shift;
	$self->_String;
	my @args	= splice(@{ $self->{stack} });
	if ($self->_test('@')) {
		my $lang	= $self->_eat( $r_LANGTAG );
		substr($lang,0,1)	= '';	# remove '@'
		push(@args, $lang);
	} elsif ($self->_test('^^')) {
		$self->_eat('^^');
		push(@args, undef);
		$self->_IRIref;
		my ($iri)	= splice(@{ $self->{stack} });
		push(@args, $iri->uri_value);
	}
	$self->_add_stack( RDF::Query::Node::Literal->new( @args ) );
}

# [61] NumericLiteral ::= NumericLiteralUnsigned | NumericLiteralPositive | NumericLiteralNegative
# [62] NumericLiteralUnsigned ::= INTEGER | DECIMAL | DOUBLE
# [63] NumericLiteralPositive ::= INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
# [64] NumericLiteralNegative ::= INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
sub _NumericLiteral {
	my $self	= shift;
	my $sign	= 1;
	if ($self->_test('+')) {
		$self->_eat('+');
	} elsif ($self->_test('-')) {
		$self->_eat('-');
		$sign	= -1;
	}
	
	my $value;
	my $type;
	if ($self->_test( $r_DOUBLE )) {
		$value	= $self->_eat( $r_DOUBLE );
		my $double	= RDF::Query::Node::Resource->new( $xsd->double->uri_value );
		$type	= $double
	} elsif ($self->_test( $r_DECIMAL )) {
		$value	= $self->_eat( $r_DECIMAL );
		my $decimal	= RDF::Query::Node::Resource->new( $xsd->decimal->uri_value );
		$type	= $decimal;
	} else {
		$value	= $self->_eat( $r_INTEGER );
		my $integer	= RDF::Query::Node::Resource->new( $xsd->integer->uri_value );
		$type	= $integer;
	}
	
	if ($sign < 0) {
		$value *= -1;
	}
	$self->_add_stack( RDF::Query::Node::Literal->new( $value, undef, $type->uri_value ) );
}

# [65] BooleanLiteral ::= 'true' | 'false'
sub _BooleanLiteral {
	my $self	= shift;
	my $bool	= $self->_eat(qr/(true|false)\b/);
	$self->_add_stack( RDF::Query::Node::Literal->new( $bool, undef, $xsd->boolean->uri_value ) );
}

# [66] String ::= STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2
sub _String {
	my $self	= shift;
	my $value;
	if ($self->_test( $r_STRING_LITERAL_LONG1 )) {
		my $string	= $self->_eat( $r_STRING_LITERAL_LONG1 );
		$value		= substr($string, 3, length($string) - 6);
	} elsif ($self->_test( $r_STRING_LITERAL_LONG2 )) {
		my $string	= $self->_eat( $r_STRING_LITERAL_LONG2 );
		$value		= substr($string, 3, length($string) - 6);
	} elsif ($self->_test( $r_STRING_LITERAL1 )) {
		my $string	= $self->_eat( $r_STRING_LITERAL1 );
		$value		= substr($string, 1, length($string) - 2);
	} else { # ($self->_test( $r_STRING_LITERAL2 )) {
		my $string	= $self->_eat( $r_STRING_LITERAL2 );
		$value		= substr($string, 1, length($string) - 2);
	}
	$value	=~ s/${r_ECHAR}/$1/g;
	$self->_add_stack( $value );
}

# [67] IRIref ::= IRI_REF | PrefixedName
sub _IRIref_test {
	my $self	= shift;
	return $self->_test(qr/<|${r_PNAME_LN}|${r_PNAME_NS}/);
}

sub _IRIref {
	my $self	= shift;
	if ($self->_test( $r_IRI_REF )) {
		my $iri	= $self->_eat( $r_IRI_REF );
		my $node	= RDF::Query::Node::Resource->new( substr($iri,1,length($iri)-2) );
		$self->_add_stack( $node );
	} else {
		$self->_PrefixedName;
	}
}

# [68] PrefixedName ::= PNAME_LN | PNAME_NS
sub _PrefixedName {
	my $self	= shift;
	if ($self->_test( $r_PNAME_LN )) {
		my $ln	= $self->_eat( $r_PNAME_LN );
		my ($ns,$local)	= split(/:/, $ln);
		if ($ns eq '') {
			$ns	= '__DEFAULT__';
		}
		my $iri		= $self->{namespaces}{$ns} . $local;
		$self->_add_stack( RDF::Query::Node::Resource->new( $iri, $self->__base ) );
	} else {
		my $ns	= $self->_eat( $r_PNAME_NS );
		if ($ns eq ':') {
			$ns	= '__DEFAULT__';
		} else {
			chop($ns);
		}
		my $iri		= $self->{namespaces}{$ns};
		$self->_add_stack( RDF::Query::Node::Resource->new( $iri, $self->__base ) );
	}
}

# [69] BlankNode ::= BLANK_NODE_LABEL | ANON
sub _BlankNode {
	my $self	= shift;
	if ($self->_test( $r_BLANK_NODE_LABEL )) {
		my $label	= $self->_eat( $r_BLANK_NODE_LABEL );
		my $id		= substr($label,2);
		$self->_add_stack( $self->new_blank($id) );
	} else {
		$self->_eat( $r_ANON );
		$self->_add_stack( $self->new_blank );
	}
}

sub _NIL {
	my $self	= shift;
	$self->_eat( $r_NIL );
	my $nil	= RDF::Query::Node::Resource->new( $rdf->nil->uri_value );
	$self->_add_stack( $nil );
}

1;

__END__

sub _var {
	my $self	= shift;
	my $name	= ;
}

sub _construct_test {
	my $self	= shift;
	return $self->_test('CONSTRUCT');
}

sub _construct {
	die;
}

sub _describe_test {
	my $self	= shift;
	return $self->_test('DESCRIBE');
}

sub _describe {
	die;
}

sub _ask_test {
	my $self	= shift;
	return $self->_test('ASK');
}

sub _ask {
	die;
}

sub _prefix_test {
	die;
}

sub _prefix {
	die;
}

sub _where_clause_test {
	my $self	= shift;
	return ($self->_test('WHERE') or $self->_test('{'));
}

sub _iri_ref {
	my $self	= shift;
	my $iri		= $self->_eat( $r_iri );
	return $self->new_uri( $iri );
}

sub _where_clause {
	my $self	= shift;
	if ($self->_test('WHERE')) {
		$self->_eat('WHERE');
		$self->__consume_ws;
	}
	
	return $self->_groupgraphpattern;
}

sub _groupgraphpattern {
	my $self	= shift;
	
	my @items;
	$self->_eat('{');
	$self->__consume_ws;
	
	if ($self->_triplesblock_test) {
		push(@items, $self->_triplesblock);
	} else { warn "###" . $self->{tokens} }
	
	while ($self->_ggpatom_test) {
		push(@items, $self->_ggpatom);
		if ($self->_test('.')) {
			$self->_eat('.');
		}
		if ($self->_triplesblock_test) {
			push(@items, $self->_triplesblock);
		}
	}
	
	$self->_eat('}');
	$self->__consume_ws;
	
	return RDF::Query::Algebra::GroupGraphPattern->new( @items );
}

sub _triplesblock_test {
	my $self	= shift;
	# Var or GraphTerm (IRIref or RDFLiteral or NumericLiteral or BooleanLiteral or BlankNode or NIL)
	warn ">>> " . substr($self->{tokens}, 0, 2);
# 	my $r	= qr/^([?$(<]|_:)/;
# 	
# 	use YAPE::Regex::Explain;
# 	my $p	= YAPE::Regex::Explain->new($r);
# 	warn $p->explain;
# 	warn $self->{tokens};
	if ($self->{tokens} =~ m/^([?$(<]|_:)/) {
		return 1;
	} else {
		return 0;
	}
}

sub _triplesblock {
	my $self	= shift;
	my @triples;
	push(@triples, $self->_triples_same_subject);
	
	while (1) {
		if ($self->_test('.')) {
			$self->_eat('.');
			if ($self->_triplesblock_test) {
				next;
			} else {
				last;
			}
		} else {
			last;
		}
	} continue {
		push(@triples, $self->_triples_same_subject);
	}
	
	return RDF::Query::Algebra::BasicGraphPattern->new( @triples );
}

sub _ggpatom_test {
	my $self	= shift;
	if ($self->{tokens} =~ /^FILTER|OPTIONAL|GRAPH|{/) {
		return 1;
	} else {
		return 0;
	}
}

sub _triples_same_subject {
	my $self	= shift;
	my $s		= $self->_var_or_term;
	$self->_ws;
	my @list	= $self->_propertylist_not_empty;
}

sub _var_or_term {
	my $self	= shift;
	if ($self->_var_test) {
		return $self->_var;
	} else {
		return $self->_graph_term;
	}
}

sub _graph_term {
	my $self	= shift;
	if ($self->_iri_ref_test) {
		return $self->_iri_ref;
	} elsif ($self->_rdf_literal_test) {
		return $self->_rdf_literal;
	} elsif ($self->_numeric_literal_test) {
		return $self->_numeric_literal;
	} elsif ($self->_boolean_literal_test) {
		return $self->_boolean_literal;
	} elsif ($self->_blank_node_test) {
		return $self->_blank_node;
	} else {
		return $self->_nil;
	}
}

sub _iri_ref_test {
	my $self	= shift;
	if ($self->{tokens} =~ m/^<[^<>"{}|^`\x92]/) {
		return 1;
	} else {
		return 0;
	}
}

sub _rdf_literal_test {
	my $self	= shift;
	if ($self->{tokens} =~ m/^(["']|""")/) {
		return 1;
	} else {
		return 0;
	}
}

sub _numeric_literal_test {
	my $self	= shift;
	if ($self->{tokens} =~ m/^([+-]?\d)/) {
		return 1;
	} else {
		return 0;
	}
}

sub _boolean_literal_test {
	my $self	= shift;
	if ($self->{tokens} =~ $r_booltest) {
		return 1;
	} else {
		return 0;
	}
}

sub _blank_node_test {
	my $self	= shift;
	if ($self->{tokens} =~ m/^(_:|\[[\n\r\t ]+\])/) {
		return 1;
	} else {
		return 0;
	}
}

sub _nil {
	my $self	= shift;
	$self->_eat( $r_nil );
}

sub _propertylist_not_empty {
	my $self	= shift;
	
	my $verb	= $self->_verb;
	$self->_ws;
	my $oblist	= $self->_objectlist;
	$self->_ws;
	
	my @list	= ($verb, $oblist);
	
	
	while ($self->_test(';')) {
		$self->_eat(';');
		$self->_ws;
		push(@list, $self->_verb);
		$self->_ws;
		push(@list, $self->_objectlist);
		$self->_ws;
	}
	return @list;
}

sub _objectlist {
	my $self	= shift;
	
	my @list	= $self->_object;
	$self->_ws;
	while ($self->_test(',')) {
		$self->_eat(',');
		$self->_ws;
		push(@list, $self->_object);
		$self->_ws;
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

sub _predicate_test {
	my $self	= shift;
	### between this and 'a'... a little tricky
	### if it's a, it'll be followed by whitespace; whitespace is mandatory
	### after a verb, which is the only thing predicate appears in
	return 0 unless (length($self->{tokens}));
	if (not $self->_test('a')) {
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

sub _uriref_test {
	my $self	= shift;
	### between this and qname
	if ($self->_test('<')) {
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

sub _relativeURI {
	my $self	= shift;
	### ucharacter*
	my $token	= $self->_eat( $r_ucharacters );
	return $token;
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


1;

__END__
################################################################################

sub _comment {
	my $self	= shift;
	### '#' ( [^#xA#xD] )*
	$self->_eat($r_comment);
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
	my $token	= $self->_eat( $r_double );
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
	my $token	= $self->_eat( $r_decimal );
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
	my $token	= $self->_eat( $r_integer );
	return $self->_typed( $token, $xsd->integer );
}

sub _boolean {
	my $self	= shift;
	### 'true' | 'false'
	my $token	= $self->_eat( $r_boolean );
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
		$self->_ws();
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
		my $ws	= $self->_eat(1);
		unless ($ws =~ /^[\n\r\t ]/) {
			throw RDF::Query::Error::ParseError -text => 'Not whitespace';
		}
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
	my $prefix	= ($self->_prefixName_test()) ? $self->_prefixName() : '';
	$self->_eat(':');
	my $name	= ($self->{tokens} =~ /^$r_nameStartChar/) ? $self->_name() : '';
	my $uri		= $self->{bindings}{$prefix};
	return $uri . $name
}

sub _language {
	my $self	= shift;
	### [a-z]+ ('-' [a-z0-9]+ )*
	my $token	= $self->_eat( $r_language );
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
	my $nc	= $self->_eat( $r_nameStartChar );
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
		my $nce	= $self->_eat( $r_nameChar_extra );
		return $nce;
	}
}

sub _name {
	my $self	= shift;
	### nameStartChar nameChar*
	my ($name)	= ($self->_eat( qr/^(${r_nameStartChar}(${r_nameStartChar}|${r_nameChar_extra})*)/ ));
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
	my $nsc	= $self->_eat( $r_nameStartChar_minus_underscore );
	push(@parts, $nsc);
#	while ($self->_nameChar_test()) {
	while ($self->{tokens} =~ /^$r_nameChar_test/) {
		my $nc	= $self->_nameChar();
		push(@parts, $nc);
	}
	return join('', @parts);
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
	my $value	= $self->_eat( $r_scharacters );
	$self->_eat('"');
	return $self->_parse_short( $value );
}

sub _longString_test {
	my $self	= shift;
	if ($self->_test( '"""' )) {
		return 1;
	} else {
		return 0;
	}
}

sub _longString {
	my $self	= shift;
      # #x22 #x22 #x22 lcharacter* #x22 #x22 #x22
	$self->_eat('"""');
	my $value	= $self->_eat( $r_lcharacters );
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
	while ($self->_ws_test()) {
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
	return RDF::Trine::Node::Blank->new( @_ )
}

sub __DatatypedLiteral {
	my $self	= shift;
	return RDF::Trine::Node::Blank->new( $_[0], undef, $_[1] )
}


1;


__END__

