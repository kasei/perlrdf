# RDF::Query::Parser::RDQL
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::RDQL - An RDQL parser for RDF::Query

=head1 VERSION

This document describes RDF::Query::Parser::RDQL version 2.918.

=cut

package RDF::Query::Parser::RDQL;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Parser);

use Data::Dumper;
use Parse::RecDescent;
use Carp qw(carp croak confess);
use RDF::Query::Error qw(:try);
use Scalar::Util qw(blessed);

######################################################################

our ($VERSION, $lang, $languri);
BEGIN {
	$::RD_TRACE	= undef;
	$::RD_HINT	= undef;
	$VERSION	= '2.918';
	$lang		= 'rdql';
	$languri	= 'http://jena.hpl.hp.com/2003/07/query/RDQL';
}

our($RDQL_GRAMMAR);
BEGIN {
	our $RDQL_GRAMMAR	= <<'END';
	query:			'SELECT' variable(s) SourceClause(?) 'WHERE' triplepattern(s) constraints(?) OptOrderBy(?) prefixes(?)
																	{
																		my $triples	= RDF::Query::Algebra::GroupGraphPattern->new( @{ $item[5] } );
																		my $filter	= ($item[6][0] || []);
																		
																		if (scalar(@$filter)) {
																			$triples	= RDF::Query::Parser->new_filter( $filter, $triples );
																		}
																		
																		$return = {
																			method		=> 'SELECT',
																			variables	=> $item[2],
																			sources		=> $item[3][0],
																			triples		=> [ $triples ],
																			namespaces	=> (scalar(@{$item[8]}) ? $item[8][0] : {})
																		};
																		if (@{ $item[7] }) {
																			$return->{options}{orderby}	= $item[9][0];
																		}
																	}
	prefixes:					'USING' namespaces								{ $return = $item[2] }
	OptOrderBy:					'ORDER BY' orderbyvariable(s)					{ $return = $item[2] }
	orderbyvariable:			variable										{ $return = ['ASC', $item[1]] }
					|			/ASC|DESC/i '[' variable ']'					{ $return = [uc($item[1]), $item[3]] }
	SourceClause:				('SOURCE' | 'FROM') Source(s)					{ $return = $item[2] }
	Source:						URI												{ $return = [$item[1]] }
	variable:					'?' identifier									{ $return = RDF::Query::Parser->new_variable($item[2]) }
	triplepattern:				'(' VarUri VarUri VarUriConst ')'				{ $return = RDF::Query::Parser::RDQL::Triple->new(@item[2,3,4]) }
	constraints:				'AND' Expression OptExpression(s?)				{
																					if (scalar(@{ $item[3] })) {
																						my ($op, $expr)	= @{ $item[3][0] };
																						$return	= RDF::Query::Parser->new_function_expression( $op, $item[2], $expr );
																					} else {
																						$return	= $item[2];
																					}
																				}
	OptExpression:				(',' | 'AND') Expression						{
																					$return = [ 'sparql:logical-and', $item[2] ];
																				}
	Expression:					CondOrExpr										{
																					$return = $item[1]
																				}
	CondOrExpr:					CondAndExpr CondOrExprOrPart(?)					{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						$return = RDF::Query::Parser->new_function_expression( $op, $item[1], $expr );
																					} else {
																						$return	= $item[1];
																					}
																				}
	CondOrExprOrPart:			'||' CondAndExpr								{ $return = [ 'sparql:logical-or', $item[2] ] }
	CondAndExpr:				ValueLogical CondAndExprAndPart(?)				{
																					if (scalar(@{ $item[2] })) {
																						$return = RDF::Query::Parser->new_function_expression( 'sparql:logical-and', $item[1], $item[2][0][1] );
																					} else {
																						$return	= $item[1];
																					}
																				}
	CondAndExprAndPart:			'&&' ValueLogical								{ $return = [ @item[1,2] ] }
	ValueLogical:				StringEqualityExpression						{ $return = $item[1] }
	StringEqualityExpression:	NumericalLogical StrEqExprPart(s?)				{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						if ($op eq '~~') {
																							$return = RDF::Query::Parser->new_function_expression( 'sparql:regex', $item[1], $expr );
																						} else {
																							$return = RDF::Query::Parser->new_binary_expression( $op, $item[1], $expr );
																						}
																					} else {
																						$return	= $item[1];
																					}
																				}
	StrEqExprPart:				('==' | '!=' | '=~' | '~~') NumericalLogical	{ $return = [ @item[1,2] ] }
	NumericalLogical:			InclusiveOrExpression							{ $return = $item[1] }
	InclusiveOrExpression:		ExclusiveOrExpression InclusiveOrExprPart(s?)	{
																					if (scalar(@{ $item[2] })) {
																						$return = [ $item[2][0][0], $item[1], $item[2][0][1] ];
																					} else {
																						$return	= $item[1];
																					}
																				}
	InclusiveOrExprPart:		'|' ExclusiveOrExpression						{ $return = [ @item[1,2] ] }
	ExclusiveOrExpression:		AndExpression ExclusiveOrExprPart(s?)			{
																					if (scalar(@{ $item[2] })) {
																						$return = [ $item[2][0][0], $item[1], map { $_->[1] } @{ $item[2] } ];
																					} else {
																						$return = $item[1];
																					}
																				}
	ExclusiveOrExprPart:		'^' AndExpression								{ $return = [ @item[1,2] ] }
	AndExpression:				ArithmeticCondition AndExprPart(s?)				{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						$return = RDF::Query::Parser->new_binary_expression( $op, $item[1], $expr );
																					} else {
																						$return = $item[1];
																					}
																				}
	AndExprPart:				'&' ArithmeticCondition							{ $return = [ @item[1,2] ] }
	ArithmeticCondition:		EqualityExpression								{ $return = $item[1]; }
	EqualityExpression:			RelationalExpression EqualityExprPart(?)		{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						$return = RDF::Query::Parser->new_binary_expression( $op, $item[1], $expr );
																					} else {
																						$return	= $item[1];
																					}
																				}
	EqualityExprPart:			/(==|!=)/ RelationalExpression					{ $return = [ @item[1,2] ] }
	RelationalExpression:		NumericExpression RelationalExprPart(?)			{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						$return = RDF::Query::Parser->new_binary_expression( $op, $item[1], $expr );
																					} else {
																						$return	= $item[1];
																					}
																				}
	RelationalExprPart:			/(<|>|<=|>=)/ NumericExpression					{ $return = [ @item[1,2] ] }
	NumericExpression:			MultiplicativeExpression NumericExprPart(s?)	{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						$return = RDF::Query::Parser->new_binary_expression( $op, $item[1], $expr );
																					} else {
																						$return	= $item[1];
																					}
																				}
	NumericExprPart:			/([-+])/ MultiplicativeExpression				{ $return = [ @item[1,2] ] }
	MultiplicativeExpression:	UnaryExpression MultExprPart(s?)				{
																					if (scalar(@{ $item[2] })) {
																						my ($op, $expr)	= @{ $item[2][0] };
																						$return = RDF::Query::Parser->new_binary_expression( $op, $item[1], $expr );
																					} else {
																						$return	= $item[1];
																					}
																				}
	MultExprPart:				/([\/*])/ UnaryExpression						{ $return = [ @item[1,2] ] }
	UnaryExpression:			UnaryExprNotPlusMinus							{ $return = $item[1] }
							|	/([-+])/ UnaryExpression						{ $return = [ @item[1,2] ] }
	UnaryExprNotPlusMinus:		/([~!])/ UnaryExpression						{ $return = [ @item[1,2] ] }
							|	PrimaryExpression								{ $return = $item[1] }
	PrimaryExpression:			(VarUriConst | FunctionCall)					{ $return = $item[1] }
							|	'(' Expression ')'								{
																					$return = $item[2];
																				}
	FunctionCall:				identifier '(' ArgList ')'						{ $return = [ 'function', map { @{ $_ } } @item[1,3] ] }
	ArgList:					VarUriConst MoreArg(s)							{ $return = [ $item[1], @{ $item[2] } ] }
	
	
	
	
	MoreArg:					"," VarUriConst									{ $return = $item[2] }
	Literal:					(URI | CONST)									{ $return = $item[1] }
	URL:						qURI											{ $return = $item[1] }
	VarUri:						(variable | URI)								{ $return = $item[1] }
	VarUriConst:				(variable | CONST | URI)						{ $return = $item[1] }
	namespaces:					namespace morenamespace(s?)						{ $return = { map { %{ $_ } } ($item[1], @{ $item[2] }) } }
	morenamespace:				OptComma namespace								{ $return = $item[2] }
	namespace:					identifier 'FOR' qURI							{ $return = {@item[1,3]} }
	OptComma:					',' | ''
	identifier:					/(([a-zA-Z0-9_.-])+)/							{ $return = $1 }
	URI:						qURI											{ $return = RDF::Query::Parser->new_uri( $item[1] ) }
							|	QName											{ $return = RDF::Query::Parser::RDQL::URI->new( $item[1] ) }
	qURI:						'<' /[A-Za-z0-9_.!~*'()%;\/?:@&=+,#\$-]+/ '>'	{ $return = $item[2] }
	QName:						identifier ':' /([^ \t<>()]+)/					{ $return = [@item[1,3]] }
	CONST:						Text											{ $return = RDF::Query::Parser->new_literal($item[1]) }
							|	Number											{ $return = RDF::Query::Parser->new_literal($item[1], undef, ($item[1] =~ /[.]/ ? 'http://www.w3.org/2001/XMLSchema#float' : 'http://www.w3.org/2001/XMLSchema#integer')) }
	Number:						/([0-9]+(\.[0-9]+)?)/							{ $return = $item[1] }
	Text:						dQText | sQText | Pattern						{ $return = $item[1] }
	sQText:						"'" /([^']+)/ '"'								{ $return = $item[2] }
	dQText:						'"' /([^"]+)/ '"'								{ $return = $item[2] }
	Pattern:					'/' /([^\/]+(?:\\.[^\/]*)*)/ '/'				{ $return = $item[2] }
END
}

######################################################################

=head1 METHODS

=over 4

=item C<new ( $query_object ) >

Returns a new RDF::Query object.

=cut

{ my $parser;
sub new {
	my $class	= shift;
	unless ($parser) {
		$parser	= new Parse::RecDescent ($RDQL_GRAMMAR);
	}
	my $self 	= bless( {
					parser		=> $parser
				}, $class );
	return $self;
} }

=item C<parse ( $query ) >

Parses the supplied RDQL query string, returning a parse tree.

=cut

sub parse {
	my $self	= shift;
	my $query	= shift;
	my $parser	= $self->parser;
	my $parsed	= $parser->query( $query );
	
	if ($parsed) {
		my $pattern	= $parsed->{triples}[0];
		if (blessed($pattern)) {
			my $ns		= $parsed->{namespaces};
			$pattern	= $self->_fixup_pattern( $pattern, $ns );
			my $fixed	= $pattern->qualify_uris( $ns );
			$parsed->{triples}[0]	= $fixed;
		}
		$pattern	= RDF::Query::Algebra::Project->new( $parsed->{triples}[0], $parsed->{variables} );
		$parsed->{triples}[0]	= $pattern;
		
		
		return $parsed;
	} else {
		return $self->fail( "Failed to parse: '$query'" );
	}
}

sub _fixup_pattern {
	my $self	= shift;
	my $pattern	= shift;
	my $ns		= shift;
	
	my @uris	= $pattern->subpatterns_of_type('RDF::Query::Parser::RDQL::URI');
	foreach my $u (@uris) {
		my $ns	= $ns->{ $u->[0] };
		my $uri	= join('', $ns, $u->[1]);
		@{ $u }	=  ( 'URI', $uri );
		bless($u, 'RDF::Query::Node::Resource');	# evil
	}
	
	my @triples	= $pattern->subpatterns_of_type('RDF::Query::Parser::RDQL::Triple');
	foreach my $t (@triples) {
		bless($t, 'RDF::Query::Algebra::Triple');	# evil
	}
	return $pattern;
}

sub AUTOLOAD {
	my $self	= $_[0];
	throw RDF::Query::Error::MethodInvocationError unless (blessed($self));
	
	my $class	= ref($_[0]);
	our $AUTOLOAD;
	return if ($AUTOLOAD =~ /DESTROY$/);
	my $method		= $AUTOLOAD;
	$method			=~ s/^.*://;
	
	if (exists($self->{ $method })) {
		no strict 'refs';
		*$AUTOLOAD	= sub {
			my $self        = shift;
			my $class       = ref($self);
			return $self->{ $method };
		};
		goto &$method;
	} else {
		throw RDF::Query::Error::MethodError ( -text => qq[Can't locate object method "$method" via package $class] );
	}
}


package RDF::Query::Parser::RDQL::URI;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

sub new {
	my $class	= shift;
	my $data	= shift;
	my ($ns, $local)	= @{ $data };
	return bless([$ns, $local], $class);
}

sub construct_args {
	my $self	= shift;
	return [ @$self ];
}

package RDF::Query::Parser::RDQL::Triple;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

sub new {
	my $class	= shift;
	my @nodes	= @_;
	return bless([@nodes], $class);
}

sub construct_args {
	my $self	= shift;
	return @$self;
}

1;

__END__

=back

=head1 REVISION HISTORY

 $Log$
 Revision 1.5  2006/01/11 06:03:45  greg
 - Removed use of Data::Dumper::Simple.

 Revision 1.4  2005/05/08 08:26:09  greg
 - Added initial support for SPARQL ASK, DESCRIBE and CONSTRUCT queries.
   - Added new test files for new query types.
 - Added methods to bridge classes for creating statements and blank nodes.
 - Added as_string method to bridge classes for getting string versions of nodes.
 - Broke out triple fixup code into fixup_triple_bridge_variables().
 - Updated FILTER test to use new Geo::Distance API.

 Revision 1.3  2005/04/26 02:54:40  greg
 - added core support for custom function constraints support
 - added initial SPARQL support for custom function constraints
 - SPARQL variables may now begin with the '$' sigil
 - broke out URL fixups into its own method
 - added direction support for ORDER BY (ascending/descending)
 - added 'next', 'current', and 'end' to Stream API

 Revision 1.2  2005/04/25 00:59:29  greg
 - streams are now objects usinig the Redland QueryResult API
 - RDF namespace is now always available in queries
 - row() now uses a stream when calling execute()
 - check_constraints() now copies args for recursive calls (instead of pass-by-ref)
 - added ORDER BY support to RDQL parser
 - SPARQL constraints now properly use the 'FILTER' keyword
 - SPARQL constraints can now use '&&' as an operator
 - SPARQL namespace declaration is now optional

 Revision 1.1  2005/04/21 02:21:44  greg
 - major changes (resurecting the project)
 - broke out the query parser into it's own RDQL class
 - added initial support for a SPARQL parser
   - added support for blank nodes
   - added lots of syntactic sugar (with blank nodes, multiple predicates and objects)
 - moved model-specific code into RDF::Query::Model::*
 - cleaned up the model-bridge code
 - moving over to redland's query API (pass in the model when query is executed)


=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
