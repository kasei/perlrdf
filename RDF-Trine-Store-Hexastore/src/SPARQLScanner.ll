/* $Id: Langname_Scanner.ll,v 1.1 2008/04/06 17:10:46 eric Exp SPARQLScanner.ll 28 2007-08-20 10:27:39Z tb $ -*- mode: c++ -*- */
/** \file SPARQLScanner.ll Define the Flex lexical scanner */

%{ /*** C/C++ Declarations ***/

#include "SPARQLParser.hh"
#include "SPARQLScanner.hh"

/* import the parser's token type into a local typedef */
typedef SPARQLNS::SPARQLParser::token token;
typedef SPARQLNS::SPARQLParser::token_type token_type;

/* Work around an incompatibility in flex (at least versions 2.5.31 through
 * 2.5.33): it generates code that does not conform to C89.  See Debian bug
 * 333231 <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=333231>.  */
#undef yywrap
#define yywrap()	1

/* By default yylex returns int, we use token_type. Unfortunately yyterminate
 * by default returns 0, which is not of token_type. */
#define yyterminate() return token::__EOF__

/* This disables inclusion of unistd.h, which is not available under Visual C++
 * on Win32. The C++ scanner uses STL streams instead. */
#define YY_NO_UNISTD_H

%}

/*** Flex Declarations and Options ***/

/* enable c++ scanner class generation */
%option c++

/* change the name of the scanner class. results in "SPARQLFlexLexer" */
%option prefix="SPARQL"

/* the manual says "somewhat more optimized" */
%option batch

/* enable scanner to generate debug output. disable this for release
 * versions. */
%option debug

/* no support for include files is planned */
%option noyywrap nounput 

/* enables the use of start condition stacks */
%option stack

/* The following paragraph suffices to track locations accurately. Each time
 * yylex is invoked, the begin position is moved onto the end position. */
%{
#define YY_USER_ACTION  yylloc->columns(yyleng);
%}

/* START patterns for SPARQL terminals */
IT_BASE		"BASE"
IT_PREFIX		"PREFIX"
IT_SELECT		"SELECT"
IT_DISTINCT		"DISTINCT"
IT_REDUCED		"REDUCED"
GT_TIMES		"*"
IT_CONSTRUCT		"CONSTRUCT"
IT_DESCRIBE		"DESCRIBE"
IT_ASK		"ASK"
IT_FROM		"FROM"
IT_NAMED		"NAMED"
IT_WHERE		"WHERE"
IT_ORDER		"ORDER"
IT_BY		"BY"
IT_ASC		"ASC"
IT_DESC		"DESC"
IT_LIMIT		"LIMIT"
IT_OFFSET		"OFFSET"
GT_LCURLEY		"{"
GT_RCURLEY		"}"
GT_DOT		"."
IT_OPTIONAL		"OPTIONAL"
IT_GRAPH		"GRAPH"
IT_UNION		"UNION"
IT_FILTER		"FILTER"
GT_COMMA		","
GT_LPAREN		"("
GT_RPAREN		")"
GT_SEMI		";"
IT_a		"a"
GT_LBRACKET		"\["
GT_RBRACKET		"\]"
GT_OR		"||"
GT_AND		"&&"
GT_EQUAL		"="
GT_NEQUAL		"!="
GT_LT		"<"
GT_GT		">"
GT_LE		"<="
GT_GE		">="
GT_PLUS		"+"
GT_MINUS		"-"
GT_DIVIDE		"/"
GT_NOT		"!"
IT_STR		"STR"
IT_LANG		"LANG"
IT_LANGMATCHES		"LANGMATCHES"
IT_DATATYPE		"DATATYPE"
IT_BOUND		"BOUND"
IT_sameTerm		"sameTerm"
IT_isIRI		"isIRI"
IT_isURI		"isURI"
IT_isBLANK		"isBLANK"
IT_isLITERAL		"isLITERAL"
IT_REGEX		"REGEX"
GT_DTYPE		"^^"
IT_true		"true"
IT_false		"false"
IRI_REF		"<"(([#-;=?-\[\]_a-z~-\x7F]|([\xC2-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF]))|([\xEE-\xEF][\x80-\xBF][\x80-\xBF])|(\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF])|(\xF4([\x80-\x8E][\x80-\xBF][\x80-\xBF])|(\x8F([\x80-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))]))*">"
LANGTAG		"@"([A-Za-z])+(("-"([0-9A-Za-z])+))*
INTEGER		([0-9])+
DECIMAL		(([0-9])+"."([0-9])*)|("."([0-9])+)
INTEGER_POSITIVE		"+"({INTEGER})
DECIMAL_POSITIVE		"+"({DECIMAL})
INTEGER_NEGATIVE		"-"({INTEGER})
DECIMAL_NEGATIVE		"-"({DECIMAL})
EXPONENT		[Ee]([+-])?([0-9])+
DOUBLE		(([0-9])+"."([0-9])*({EXPONENT}))|(("."(([0-9]))+({EXPONENT}))|((([0-9]))+({EXPONENT})))
DOUBLE_NEGATIVE		"-"({DOUBLE})
DOUBLE_POSITIVE		"+"({DOUBLE})
ECHAR		"\\"[\"'\\bfnrt]
STRING_LITERAL_LONG2		"\"\"\""((((("\"")|("\"\"")))?(([\x00-!#-\[\]-\x7F]|([\xC2-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF]))|([\xEE-\xEF][\x80-\xBF][\x80-\xBF])|(\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF])|(\xF4([\x80-\x8E][\x80-\xBF][\x80-\xBF])|(\x8F([\x80-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))])|(({ECHAR})))))*"\"\"\""
STRING_LITERAL_LONG1		"'''"((((("'")|("''")))?(([\x00-&(-\[\]-\x7F]|([\xC2-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF]))|([\xEE-\xEF][\x80-\xBF][\x80-\xBF])|(\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF])|(\xF4([\x80-\x8E][\x80-\xBF][\x80-\xBF])|(\x8F([\x80-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))])|(({ECHAR})))))*"'''"
STRING_LITERAL2		"\""(((([\x00-\t\x0B-\x0C\x0E-!#-\[\]-\x7F]|([\xC2-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF]))|([\xEE-\xEF][\x80-\xBF][\x80-\xBF])|(\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF])|(\xF4([\x80-\x8E][\x80-\xBF][\x80-\xBF])|(\x8F([\x80-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))]))|(({ECHAR}))))*"\""
STRING_LITERAL1		"'"(((([\x00-\t\x0B-\x0C\x0E-&(-\[\]-\x7F]|([\xC2-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF]))|([\xEE-\xEF][\x80-\xBF][\x80-\xBF])|(\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF])|(\xF4([\x80-\x8E][\x80-\xBF][\x80-\xBF])|(\x8F([\x80-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))]))|(({ECHAR}))))*"'"
WS		(" ")|(("\t")|(("\r")|("\n")))
NIL		"("(({WS}))*")"
ANON		"\["(({WS}))*"\]"
PN_CHARS_BASE		([A-Z])|(([a-z])|(((\xC3[\x80-\x96]))|(((\xC3[\x98-\xB6]))|(((\xC3[\xB8-\xBF])|([\xC4-\xCB][\x80-\xBF]))|(((\xCD[\xB0-\xBD]))|(((\xCD\xBF)|([\xCE-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|(\xE1([\x80-\xBF][\x80-\xBF])))|(((\xE2(\x80[\x8C-\x8D])))|(((\xE2(\x81[\xB0-\xBF])|([\x82-\x85][\x80-\xBF])|(\x86[\x80-\x8F])))|(((\xE2([\xB0-\xBE][\x80-\xBF])|(\xBF[\x80-\xAF])))|(((\xE3(\x80[\x81-\xBF])|([\x81-\xBF][\x80-\xBF]))|([\xE4-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF])))|(((\xEF([\xA4-\xB6][\x80-\xBF])|(\xB7[\x80-\x8F])))|(((\xEF(\xB7[\xB0-\xBF])|([\xB8-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))|((\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF]))))))))))))))
PN_CHARS_U		(({PN_CHARS_BASE}))|("_")
VARNAME		((({PN_CHARS_U}))|([0-9]))(((({PN_CHARS_U}))|(([0-9])|((\xC2\xB7)|(((\xCD[\x80-\xAF]))|((\xE2(\x80\xBF)|(\x81\x80))))))))*
VAR2		"$"({VARNAME})
VAR1		"?"({VARNAME})
PN_CHARS		(({PN_CHARS_U}))|(("-")|(([0-9])|((\xC2\xB7)|(((\xCD[\x80-\xAF]))|((\xE2(\x80\xBF)|(\x81\x80)))))))
PN_PREFIX		({PN_CHARS_BASE})(((((({PN_CHARS}))|(".")))*({PN_CHARS})))?
PNAME_NS		(({PN_PREFIX}))?":"
PN_LOCAL		((({PN_CHARS_U}))|([0-9]))(((((({PN_CHARS}))|(".")))*({PN_CHARS})))?
BLANK_NODE_LABEL		"_:"({PN_LOCAL})
PNAME_LN		({PNAME_NS})({PN_LOCAL})
PASSED_TOKENS		(([\t\n\r ])+)|("#"([\x00-\t\x0B-\x0C\x0E-\x7F]|([\xC2-\xDF][\x80-\xBF])|(\xE0([\xA0-\xBF][\x80-\xBF]))|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|([\xE1-\xEC][\x80-\xBF][\x80-\xBF])|(\xED([\x80-\x9F][\x80-\xBF]))|([\xEE-\xEF][\x80-\xBF][\x80-\xBF])|(\xF0([\x90-\xBF][\x80-\xBF][\x80-\xBF]))|([\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF])|(\xF4([\x80-\x8E][\x80-\xBF][\x80-\xBF])|(\x8F([\x80-\xBE][\x80-\xBF])|(\xBF[\x80-\xBD])))])*)

/* END patterns for SPARQL terminals */

/* START semantic actions for SPARQL terminals */
%%
{PASSED_TOKENS}		{ /* yylloc->step(); @@ needed? useful? */ }
{IT_BASE}		{yylval->p_IT_BASE = new IT_BASE(); return token::IT_BASE;}
{IT_PREFIX}		{yylval->p_IT_PREFIX = new IT_PREFIX(); return token::IT_PREFIX;}
{IT_SELECT}		{yylval->p_IT_SELECT = new IT_SELECT(); return token::IT_SELECT;}
{IT_DISTINCT}		{yylval->p_IT_DISTINCT = new IT_DISTINCT(); return token::IT_DISTINCT;}
{IT_REDUCED}		{yylval->p_IT_REDUCED = new IT_REDUCED(); return token::IT_REDUCED;}
{GT_TIMES}		{yylval->p_GT_TIMES = new GT_TIMES(); return token::GT_TIMES;}
{IT_CONSTRUCT}		{yylval->p_IT_CONSTRUCT = new IT_CONSTRUCT(); return token::IT_CONSTRUCT;}
{IT_DESCRIBE}		{yylval->p_IT_DESCRIBE = new IT_DESCRIBE(); return token::IT_DESCRIBE;}
{IT_ASK}		{yylval->p_IT_ASK = new IT_ASK(); return token::IT_ASK;}
{IT_FROM}		{yylval->p_IT_FROM = new IT_FROM(); return token::IT_FROM;}
{IT_NAMED}		{yylval->p_IT_NAMED = new IT_NAMED(); return token::IT_NAMED;}
{IT_WHERE}		{yylval->p_IT_WHERE = new IT_WHERE(); return token::IT_WHERE;}
{IT_ORDER}		{yylval->p_IT_ORDER = new IT_ORDER(); return token::IT_ORDER;}
{IT_BY}		{yylval->p_IT_BY = new IT_BY(); return token::IT_BY;}
{IT_ASC}		{yylval->p_IT_ASC = new IT_ASC(); return token::IT_ASC;}
{IT_DESC}		{yylval->p_IT_DESC = new IT_DESC(); return token::IT_DESC;}
{IT_LIMIT}		{yylval->p_IT_LIMIT = new IT_LIMIT(); return token::IT_LIMIT;}
{IT_OFFSET}		{yylval->p_IT_OFFSET = new IT_OFFSET(); return token::IT_OFFSET;}
{GT_LCURLEY}		{yylval->p_GT_LCURLEY = new GT_LCURLEY(); return token::GT_LCURLEY;}
{GT_RCURLEY}		{yylval->p_GT_RCURLEY = new GT_RCURLEY(); return token::GT_RCURLEY;}
{GT_DOT}		{yylval->p_GT_DOT = new GT_DOT(); return token::GT_DOT;}
{IT_OPTIONAL}		{yylval->p_IT_OPTIONAL = new IT_OPTIONAL(); return token::IT_OPTIONAL;}
{IT_GRAPH}		{yylval->p_IT_GRAPH = new IT_GRAPH(); return token::IT_GRAPH;}
{IT_UNION}		{yylval->p_IT_UNION = new IT_UNION(); return token::IT_UNION;}
{IT_FILTER}		{yylval->p_IT_FILTER = new IT_FILTER(); return token::IT_FILTER;}
{GT_COMMA}		{yylval->p_GT_COMMA = new GT_COMMA(); return token::GT_COMMA;}
{GT_LPAREN}		{yylval->p_GT_LPAREN = new GT_LPAREN(); return token::GT_LPAREN;}
{GT_RPAREN}		{yylval->p_GT_RPAREN = new GT_RPAREN(); return token::GT_RPAREN;}
{GT_SEMI}		{yylval->p_GT_SEMI = new GT_SEMI(); return token::GT_SEMI;}
{IT_a}		{yylval->p_IT_a = new IT_a(); return token::IT_a;}
{GT_LBRACKET}		{yylval->p_GT_LBRACKET = new GT_LBRACKET(); return token::GT_LBRACKET;}
{GT_RBRACKET}		{yylval->p_GT_RBRACKET = new GT_RBRACKET(); return token::GT_RBRACKET;}
{GT_OR}		{yylval->p_GT_OR = new GT_OR(); return token::GT_OR;}
{GT_AND}		{yylval->p_GT_AND = new GT_AND(); return token::GT_AND;}
{GT_EQUAL}		{yylval->p_GT_EQUAL = new GT_EQUAL(); return token::GT_EQUAL;}
{GT_NEQUAL}		{yylval->p_GT_NEQUAL = new GT_NEQUAL(); return token::GT_NEQUAL;}
{GT_LT}		{yylval->p_GT_LT = new GT_LT(); return token::GT_LT;}
{GT_GT}		{yylval->p_GT_GT = new GT_GT(); return token::GT_GT;}
{GT_LE}		{yylval->p_GT_LE = new GT_LE(); return token::GT_LE;}
{GT_GE}		{yylval->p_GT_GE = new GT_GE(); return token::GT_GE;}
{GT_PLUS}		{yylval->p_GT_PLUS = new GT_PLUS(); return token::GT_PLUS;}
{GT_MINUS}		{yylval->p_GT_MINUS = new GT_MINUS(); return token::GT_MINUS;}
{GT_DIVIDE}		{yylval->p_GT_DIVIDE = new GT_DIVIDE(); return token::GT_DIVIDE;}
{GT_NOT}		{yylval->p_GT_NOT = new GT_NOT(); return token::GT_NOT;}
{IT_STR}		{yylval->p_IT_STR = new IT_STR(); return token::IT_STR;}
{IT_LANG}		{yylval->p_IT_LANG = new IT_LANG(); return token::IT_LANG;}
{IT_LANGMATCHES}		{yylval->p_IT_LANGMATCHES = new IT_LANGMATCHES(); return token::IT_LANGMATCHES;}
{IT_DATATYPE}		{yylval->p_IT_DATATYPE = new IT_DATATYPE(); return token::IT_DATATYPE;}
{IT_BOUND}		{yylval->p_IT_BOUND = new IT_BOUND(); return token::IT_BOUND;}
{IT_sameTerm}		{yylval->p_IT_sameTerm = new IT_sameTerm(); return token::IT_sameTerm;}
{IT_isIRI}		{yylval->p_IT_isIRI = new IT_isIRI(); return token::IT_isIRI;}
{IT_isURI}		{yylval->p_IT_isURI = new IT_isURI(); return token::IT_isURI;}
{IT_isBLANK}		{yylval->p_IT_isBLANK = new IT_isBLANK(); return token::IT_isBLANK;}
{IT_isLITERAL}		{yylval->p_IT_isLITERAL = new IT_isLITERAL(); return token::IT_isLITERAL;}
{IT_REGEX}		{yylval->p_IT_REGEX = new IT_REGEX(); return token::IT_REGEX;}
{GT_DTYPE}		{yylval->p_GT_DTYPE = new GT_DTYPE(); return token::GT_DTYPE;}
{IT_true}		{yylval->p_IT_true = new IT_true(); return token::IT_true;}
{IT_false}		{yylval->p_IT_false = new IT_false(); return token::IT_false;}
{IRI_REF}		{yylval->p_IRI_REF = new IRI_REF(yytext); return token::IRI_REF;}
{PNAME_NS}		{yylval->p_PNAME_NS = new PNAME_NS(yytext); return token::PNAME_NS;}
{PNAME_LN}		{yylval->p_PNAME_LN = new PNAME_LN(yytext); return token::PNAME_LN;}
{BLANK_NODE_LABEL}		{yylval->p_BLANK_NODE_LABEL = new BLANK_NODE_LABEL(yytext); return token::BLANK_NODE_LABEL;}
{VAR1}		{yylval->p_VAR1 = new VAR1(yytext); return token::VAR1;}
{VAR2}		{yylval->p_VAR2 = new VAR2(yytext); return token::VAR2;}
{LANGTAG}		{yylval->p_LANGTAG = new LANGTAG(yytext); return token::LANGTAG;}
{INTEGER}		{yylval->p_INTEGER = new INTEGER(yytext); return token::INTEGER;}
{DECIMAL}		{yylval->p_DECIMAL = new DECIMAL(yytext); return token::DECIMAL;}
{DOUBLE}		{yylval->p_DOUBLE = new DOUBLE(yytext); return token::DOUBLE;}
{INTEGER_POSITIVE}		{yylval->p_INTEGER_POSITIVE = new INTEGER_POSITIVE(yytext); return token::INTEGER_POSITIVE;}
{DECIMAL_POSITIVE}		{yylval->p_DECIMAL_POSITIVE = new DECIMAL_POSITIVE(yytext); return token::DECIMAL_POSITIVE;}
{DOUBLE_POSITIVE}		{yylval->p_DOUBLE_POSITIVE = new DOUBLE_POSITIVE(yytext); return token::DOUBLE_POSITIVE;}
{INTEGER_NEGATIVE}		{yylval->p_INTEGER_NEGATIVE = new INTEGER_NEGATIVE(yytext); return token::INTEGER_NEGATIVE;}
{DECIMAL_NEGATIVE}		{yylval->p_DECIMAL_NEGATIVE = new DECIMAL_NEGATIVE(yytext); return token::DECIMAL_NEGATIVE;}
{DOUBLE_NEGATIVE}		{yylval->p_DOUBLE_NEGATIVE = new DOUBLE_NEGATIVE(yytext); return token::DOUBLE_NEGATIVE;}
{STRING_LITERAL1}		{yylval->p_STRING_LITERAL1 = new STRING_LITERAL1(yytext); return token::STRING_LITERAL1;}
{STRING_LITERAL2}		{yylval->p_STRING_LITERAL2 = new STRING_LITERAL2(yytext); return token::STRING_LITERAL2;}
{STRING_LITERAL_LONG1}		{yylval->p_STRING_LITERAL_LONG1 = new STRING_LITERAL_LONG1(yytext); return token::STRING_LITERAL_LONG1;}
{STRING_LITERAL_LONG2}		{yylval->p_STRING_LITERAL_LONG2 = new STRING_LITERAL_LONG2(yytext); return token::STRING_LITERAL_LONG2;}
{NIL}		{yylval->p_NIL = new NIL(yytext); return token::NIL;}
{ANON}		{yylval->p_ANON = new ANON(yytext); return token::ANON;}

<<EOF>>			{ yyterminate();}
%%
/* END semantic actions for SPARQL terminals */

/* START SPARQLScanner */
namespace SPARQLNS {

SPARQLScanner::SPARQLScanner(std::istream* in,
		 std::ostream* out)
    : SPARQLFlexLexer(in, out)
{
}

SPARQLScanner::~SPARQLScanner()
{
}

void SPARQLScanner::set_debug(bool b)
{
    yy_flex_debug = b;
}

}
/* END SPARQLScanner */

/* This implementation of SPARQLFlexLexer::yylex() is required to fill the
 * vtable of the class SPARQLFlexLexer. We define the scanner's main yylex
 * function via YY_DECL to reside in the SPARQLScanner class instead. */

#ifdef yylex
#undef yylex
#endif

int SPARQLFlexLexer::yylex()
{
    std::cerr << "in SPARQLFlexLexer::yylex() !" << std::endl;
    return 0;
}

