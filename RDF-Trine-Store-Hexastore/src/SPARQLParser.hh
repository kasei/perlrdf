/* A Bison parser, made by GNU Bison 2.3.  */

/* Skeleton interface for Bison LALR(1) parsers in C++

   Copyright (C) 2002, 2003, 2004, 2005, 2006 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C++ LALR(1) parser skeleton written by Akim Demaille.  */

#ifndef PARSER_HEADER_H
# define PARSER_HEADER_H

#include <string>
#include <iostream>
#include "stack.hh"

namespace SPARQLNS
{
  class position;
  class location;
}

/* First part of user declarations.  */
#line 44 "SPARQLParser.yy"
 /*** C/C++ Declarations ***/

extern std::ostream* _Trace;

#include <fstream>
#include <iostream>
#include <sstream>


/* START ClassBlock */
class _Base {
public:
    virtual const char * getProductionName() = 0;
    virtual const char * toStr(std::ofstream* out = NULL) = 0;
    virtual const char * toXml(size_t depth, std::ofstream* out = NULL) = 0;
    virtual size_t toAbsorb () { return 1; }
    virtual _Base* absorb (size_t) { return this; }
    virtual ~_Base() { }
};
class _Production : public _Base {
protected:
    void trace(const char * name, size_t argc, ...);
    const char * toStr(std::ofstream* out, size_t argc, ...);
    const char * toXml(size_t depth, std::ofstream* out, size_t argc, ...);
    virtual void openXmlFrame(char* ret, size_t* pNowAt, size_t depth);
    virtual void closeXmlFrame(char* ret, size_t* pNowAt);
};
class _GenProduction : public _Production {
private:
    size_t size;
    _Base** vals;
protected:
    _GenProduction(const char* productionName, size_t argc, ...);
    virtual size_t toAbsorb () { return size; }
    virtual _Base* absorb (size_t index) { return vals[index]; }
    virtual void openXmlFrame(char* ret, size_t* pNowAt, size_t depth);
    virtual void closeXmlFrame(char* ret, size_t* pNowAt);
public:
    virtual const char* toStr(std::ofstream* out = NULL);
    virtual const char* toXml(size_t depth, std::ofstream* out = NULL);
};
class _Token : public _Base {
protected:
    _Token () { }
    void trace();
private:
    virtual const char * getToken() = 0;
public:
    virtual const char* toStr(std::ofstream* out = NULL);
    virtual const char* toXml(size_t depth, std::ofstream* out = NULL);
};
class _Terminal : public _Base {
private:
    const char * terminal;
protected:
    _Terminal (const char * p) {
	terminal = new char[strlen(p) + 1];
	strcpy((char*)terminal, p); // @@ should initialize as member
    }
    void trace();
public:
    virtual const char* toStr(std::ofstream* out = NULL);
    virtual const char* toXml(size_t depth, std::ofstream* out = NULL);
};

class Query;
class _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C;
class Prologue;
class _QBaseDecl_E_Opt;
class _QPrefixDecl_E_Star;
class BaseDecl;
class PrefixDecl;
class SelectQuery;
class _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C;
class _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt;
class _QVar_E_Plus;
class _O_QVar_E_Plus_Or_QGT_TIMES_E_C;
class _QDatasetClause_E_Star;
class ConstructQuery;
class DescribeQuery;
class _QVarOrIRIref_E_Plus;
class _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C;
class _QWhereClause_E_Opt;
class AskQuery;
class DatasetClause;
class _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C;
class DefaultGraphClause;
class NamedGraphClause;
class SourceSelector;
class WhereClause;
class _QIT_WHERE_E_Opt;
class SolutionModifier;
class _QOrderClause_E_Opt;
class _QLimitOffsetClauses_E_Opt;
class LimitOffsetClauses;
class _QOffsetClause_E_Opt;
class _QLimitClause_E_Opt;
class _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C;
class OrderClause;
class _QOrderCondition_E_Plus;
class OrderCondition;
class _O_QIT_ASC_E_Or_QIT_DESC_E_C;
class _O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C;
class _O_QConstraint_E_Or_QVar_E_C;
class LimitClause;
class OffsetClause;
class GroupGraphPattern;
class _QTriplesBlock_E_Opt;
class _O_QGraphPatternNotTriples_E_Or_QFilter_E_C;
class _QGT_DOT_E_Opt;
class _O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C;
class _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star;
class TriplesBlock;
class _O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C;
class _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt;
class GraphPatternNotTriples;
class OptionalGraphPattern;
class GraphGraphPattern;
class GroupOrUnionGraphPattern;
class _O_QIT_UNION_E_S_QGroupGraphPattern_E_C;
class _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star;
class Filter;
class Constraint;
class FunctionCall;
class ArgList;
class _O_QGT_COMMA_E_S_QExpression_E_C;
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star;
class _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C;
class ConstructTemplate;
class _QConstructTriples_E_Opt;
class ConstructTriples;
class _O_QGT_DOT_E_S_QConstructTriples_E_Opt_C;
class _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt;
class TriplesSameSubject;
class PropertyListNotEmpty;
class _O_QVerb_E_S_QObjectList_E_C;
class _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt;
class _O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C;
class _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star;
class PropertyList;
class _QPropertyListNotEmpty_E_Opt;
class ObjectList;
class _O_QGT_COMMA_E_S_QObject_E_C;
class _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star;
class Object;
class Verb;
class TriplesNode;
class BlankNodePropertyList;
class Collection;
class _QGraphNode_E_Plus;
class GraphNode;
class VarOrTerm;
class VarOrIRIref;
class Var;
class GraphTerm;
class Expression;
class ConditionalOrExpression;
class _O_QGT_OR_E_S_QConditionalAndExpression_E_C;
class _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star;
class ConditionalAndExpression;
class _O_QGT_AND_E_S_QValueLogical_E_C;
class _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star;
class ValueLogical;
class RelationalExpression;
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C;
class _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt;
class NumericExpression;
class AdditiveExpression;
class _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C;
class _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star;
class MultiplicativeExpression;
class _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C;
class _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star;
class UnaryExpression;
class PrimaryExpression;
class BrackettedExpression;
class BuiltInCall;
class RegexExpression;
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt;
class IRIrefOrFunction;
class _QArgList_E_Opt;
class RDFLiteral;
class _O_QGT_DTYPE_E_S_QIRIref_E_C;
class _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C;
class _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt;
class NumericLiteral;
class NumericLiteralUnsigned;
class NumericLiteralPositive;
class NumericLiteralNegative;
class BooleanLiteral;
class String;
class IRIref;
class PrefixedName;
class BlankNode;

class IT_BASE;
class IT_PREFIX;
class IT_SELECT;
class IT_DISTINCT;
class IT_REDUCED;
class GT_TIMES;
class IT_CONSTRUCT;
class IT_DESCRIBE;
class IT_ASK;
class IT_FROM;
class IT_NAMED;
class IT_WHERE;
class IT_ORDER;
class IT_BY;
class IT_ASC;
class IT_DESC;
class IT_LIMIT;
class IT_OFFSET;
class GT_LCURLEY;
class GT_RCURLEY;
class GT_DOT;
class IT_OPTIONAL;
class IT_GRAPH;
class IT_UNION;
class IT_FILTER;
class GT_COMMA;
class GT_LPAREN;
class GT_RPAREN;
class GT_SEMI;
class IT_a;
class GT_LBRACKET;
class GT_RBRACKET;
class GT_OR;
class GT_AND;
class GT_EQUAL;
class GT_NEQUAL;
class GT_LT;
class GT_GT;
class GT_LE;
class GT_GE;
class GT_PLUS;
class GT_MINUS;
class GT_DIVIDE;
class GT_NOT;
class IT_STR;
class IT_LANG;
class IT_LANGMATCHES;
class IT_DATATYPE;
class IT_BOUND;
class IT_sameTerm;
class IT_isIRI;
class IT_isURI;
class IT_isBLANK;
class IT_isLITERAL;
class IT_REGEX;
class GT_DTYPE;
class IT_true;
class IT_false;
class IRI_REF;
class PNAME_NS;
class PNAME_LN;
class BLANK_NODE_LABEL;
class VAR1;
class VAR2;
class LANGTAG;
class INTEGER;
class DECIMAL;
class DOUBLE;
class INTEGER_POSITIVE;
class DECIMAL_POSITIVE;
class DOUBLE_POSITIVE;
class INTEGER_NEGATIVE;
class DECIMAL_NEGATIVE;
class DOUBLE_NEGATIVE;
class STRING_LITERAL1;
class STRING_LITERAL2;
class STRING_LITERAL_LONG1;
class STRING_LITERAL_LONG2;
class NIL;
class ANON;


class Query : public _Production {
private:
    Prologue* m_Prologue;
    _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C* m__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C;
    virtual const char* getProductionName () { return "Query"; }
public:
    Query (Prologue* p_Prologue, _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C* p__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C) {
	m_Prologue = p_Prologue;
	m__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C = p__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C;
	trace("Query", 2, p_Prologue, p__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_Prologue, m__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_Prologue, m__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C);}
};
class _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C"; }
};
class _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule0 : public _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C {
private:
    SelectQuery* m_SelectQuery;
public:
    _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule0 (SelectQuery* p_SelectQuery) {
	m_SelectQuery = p_SelectQuery;
	trace("_O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C", 1, p_SelectQuery);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_SelectQuery);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_SelectQuery);}
};
class _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule1 : public _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C {
private:
    ConstructQuery* m_ConstructQuery;
public:
    _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule1 (ConstructQuery* p_ConstructQuery) {
	m_ConstructQuery = p_ConstructQuery;
	trace("_O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C", 1, p_ConstructQuery);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_ConstructQuery);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_ConstructQuery);}
};
class _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule2 : public _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C {
private:
    DescribeQuery* m_DescribeQuery;
public:
    _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule2 (DescribeQuery* p_DescribeQuery) {
	m_DescribeQuery = p_DescribeQuery;
	trace("_O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C", 1, p_DescribeQuery);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DescribeQuery);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DescribeQuery);}
};
class _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule3 : public _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C {
private:
    AskQuery* m_AskQuery;
public:
    _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C_rule3 (AskQuery* p_AskQuery) {
	m_AskQuery = p_AskQuery;
	trace("_O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C", 1, p_AskQuery);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_AskQuery);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_AskQuery);}
};
class Prologue : public _Production {
private:
    _QBaseDecl_E_Opt* m__QBaseDecl_E_Opt;
    _QPrefixDecl_E_Star* m__QPrefixDecl_E_Star;
    virtual const char* getProductionName () { return "Prologue"; }
public:
    Prologue (_QBaseDecl_E_Opt* p__QBaseDecl_E_Opt, _QPrefixDecl_E_Star* p__QPrefixDecl_E_Star) {
	m__QBaseDecl_E_Opt = p__QBaseDecl_E_Opt;
	m__QPrefixDecl_E_Star = p__QPrefixDecl_E_Star;
	trace("Prologue", 2, p__QBaseDecl_E_Opt, p__QPrefixDecl_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m__QBaseDecl_E_Opt, m__QPrefixDecl_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m__QBaseDecl_E_Opt, m__QPrefixDecl_E_Star);}
};
class _QBaseDecl_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QBaseDecl_E_Opt"; }
};
class _QBaseDecl_E_Opt_rule0 : public _QBaseDecl_E_Opt {
public:
    _QBaseDecl_E_Opt_rule0 () {
	trace("_QBaseDecl_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QBaseDecl_E_Opt_rule1 : public _QBaseDecl_E_Opt {
private:
    BaseDecl* m_BaseDecl;
public:
    _QBaseDecl_E_Opt_rule1 (BaseDecl* p_BaseDecl) {
	m_BaseDecl = p_BaseDecl;
	trace("_QBaseDecl_E_Opt", 1, p_BaseDecl);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BaseDecl);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BaseDecl);}
};
class _QPrefixDecl_E_Star : public _GenProduction {
protected:
    _QPrefixDecl_E_Star () : 
    _GenProduction("_QPrefixDecl_E_Star", 0) {}
    _QPrefixDecl_E_Star (PrefixDecl* p_PrefixDecl) : 
    _GenProduction("_QPrefixDecl_E_Star", 1, p_PrefixDecl) {}
    _QPrefixDecl_E_Star (_QPrefixDecl_E_Star* p__QPrefixDecl_E_Star, PrefixDecl* p_PrefixDecl) : 
    _GenProduction("_QPrefixDecl_E_Star", 2, p__QPrefixDecl_E_Star, p_PrefixDecl) {}
    virtual const char * getProductionName () { return "_QPrefixDecl_E_Star"; }
};
class _QPrefixDecl_E_Star_rule0 : public _QPrefixDecl_E_Star {
public:
    _QPrefixDecl_E_Star_rule0 () : 
    _QPrefixDecl_E_Star() {
	trace("_QPrefixDecl_E_Star", 0);
    }
};
class _QPrefixDecl_E_Star_rule1 : public _QPrefixDecl_E_Star {
public:
    _QPrefixDecl_E_Star_rule1 (_QPrefixDecl_E_Star* p__QPrefixDecl_E_Star, PrefixDecl* p_PrefixDecl) : 
    _QPrefixDecl_E_Star(p__QPrefixDecl_E_Star, p_PrefixDecl) {
	trace("_QPrefixDecl_E_Star", 2, p__QPrefixDecl_E_Star, p_PrefixDecl);
	delete p__QPrefixDecl_E_Star;
    }
};
class BaseDecl : public _Production {
private:
    IT_BASE* m_IT_BASE;
    IRI_REF* m_IRI_REF;
    virtual const char* getProductionName () { return "BaseDecl"; }
public:
    BaseDecl (IT_BASE* p_IT_BASE, IRI_REF* p_IRI_REF) {
	m_IT_BASE = p_IT_BASE;
	m_IRI_REF = p_IRI_REF;
	trace("BaseDecl", 2, p_IT_BASE, p_IRI_REF);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_BASE, m_IRI_REF);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_BASE, m_IRI_REF);}
};
class PrefixDecl : public _Production {
private:
    IT_PREFIX* m_IT_PREFIX;
    PNAME_NS* m_PNAME_NS;
    IRI_REF* m_IRI_REF;
    virtual const char* getProductionName () { return "PrefixDecl"; }
public:
    PrefixDecl (IT_PREFIX* p_IT_PREFIX, PNAME_NS* p_PNAME_NS, IRI_REF* p_IRI_REF) {
	m_IT_PREFIX = p_IT_PREFIX;
	m_PNAME_NS = p_PNAME_NS;
	m_IRI_REF = p_IRI_REF;
	trace("PrefixDecl", 3, p_IT_PREFIX, p_PNAME_NS, p_IRI_REF);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_IT_PREFIX, m_PNAME_NS, m_IRI_REF);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_IT_PREFIX, m_PNAME_NS, m_IRI_REF);}
};
class SelectQuery : public _Production {
private:
    IT_SELECT* m_IT_SELECT;
    _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt* m__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt;
    _O_QVar_E_Plus_Or_QGT_TIMES_E_C* m__O_QVar_E_Plus_Or_QGT_TIMES_E_C;
    _QDatasetClause_E_Star* m__QDatasetClause_E_Star;
    WhereClause* m_WhereClause;
    SolutionModifier* m_SolutionModifier;
    virtual const char* getProductionName () { return "SelectQuery"; }
public:
    SelectQuery (IT_SELECT* p_IT_SELECT, _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt* p__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt, _O_QVar_E_Plus_Or_QGT_TIMES_E_C* p__O_QVar_E_Plus_Or_QGT_TIMES_E_C, _QDatasetClause_E_Star* p__QDatasetClause_E_Star, WhereClause* p_WhereClause, SolutionModifier* p_SolutionModifier) {
	m_IT_SELECT = p_IT_SELECT;
	m__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt = p__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt;
	m__O_QVar_E_Plus_Or_QGT_TIMES_E_C = p__O_QVar_E_Plus_Or_QGT_TIMES_E_C;
	m__QDatasetClause_E_Star = p__QDatasetClause_E_Star;
	m_WhereClause = p_WhereClause;
	m_SolutionModifier = p_SolutionModifier;
	trace("SelectQuery", 6, p_IT_SELECT, p__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt, p__O_QVar_E_Plus_Or_QGT_TIMES_E_C, p__QDatasetClause_E_Star, p_WhereClause, p_SolutionModifier);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 6, m_IT_SELECT, m__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt, m__O_QVar_E_Plus_Or_QGT_TIMES_E_C, m__QDatasetClause_E_Star, m_WhereClause, m_SolutionModifier);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 6, m_IT_SELECT, m__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt, m__O_QVar_E_Plus_Or_QGT_TIMES_E_C, m__QDatasetClause_E_Star, m_WhereClause, m_SolutionModifier);}
};
class _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C"; }
};
class _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_rule0 : public _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C {
private:
    IT_DISTINCT* m_IT_DISTINCT;
public:
    _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_rule0 (IT_DISTINCT* p_IT_DISTINCT) {
	m_IT_DISTINCT = p_IT_DISTINCT;
	trace("_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C", 1, p_IT_DISTINCT);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_DISTINCT);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_DISTINCT);}
};
class _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_rule1 : public _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C {
private:
    IT_REDUCED* m_IT_REDUCED;
public:
    _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_rule1 (IT_REDUCED* p_IT_REDUCED) {
	m_IT_REDUCED = p_IT_REDUCED;
	trace("_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C", 1, p_IT_REDUCED);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_REDUCED);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_REDUCED);}
};
class _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt"; }
};
class _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt_rule0 : public _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt {
public:
    _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt_rule0 () {
	trace("_Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt_rule1 : public _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt {
private:
    _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C* m__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C;
public:
    _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt_rule1 (_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C* p__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C) {
	m__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C = p__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C;
	trace("_Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt", 1, p__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C);}
};
class _QVar_E_Plus : public _GenProduction {
protected:
    _QVar_E_Plus () : 
    _GenProduction("_QVar_E_Plus", 0) {}
    _QVar_E_Plus (Var* p_Var) : 
    _GenProduction("_QVar_E_Plus", 1, p_Var) {}
    _QVar_E_Plus (_QVar_E_Plus* p__QVar_E_Plus, Var* p_Var) : 
    _GenProduction("_QVar_E_Plus", 2, p__QVar_E_Plus, p_Var) {}
    virtual const char * getProductionName () { return "_QVar_E_Plus"; }
};
class _QVar_E_Plus_rule0 : public _QVar_E_Plus {
public:
    _QVar_E_Plus_rule0 (Var* p_Var) : 
    _QVar_E_Plus(p_Var) {
	trace("_QVar_E_Plus", 1, p_Var);
    }
};
class _QVar_E_Plus_rule1 : public _QVar_E_Plus {
public:
    _QVar_E_Plus_rule1 (_QVar_E_Plus* p__QVar_E_Plus, Var* p_Var) : 
    _QVar_E_Plus(p__QVar_E_Plus, p_Var) {
	trace("_QVar_E_Plus", 2, p__QVar_E_Plus, p_Var);
	delete p__QVar_E_Plus;
    }
};
class _O_QVar_E_Plus_Or_QGT_TIMES_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QVar_E_Plus_Or_QGT_TIMES_E_C"; }
};
class _O_QVar_E_Plus_Or_QGT_TIMES_E_C_rule0 : public _O_QVar_E_Plus_Or_QGT_TIMES_E_C {
private:
    _QVar_E_Plus* m__QVar_E_Plus;
public:
    _O_QVar_E_Plus_Or_QGT_TIMES_E_C_rule0 (_QVar_E_Plus* p__QVar_E_Plus) {
	m__QVar_E_Plus = p__QVar_E_Plus;
	trace("_O_QVar_E_Plus_Or_QGT_TIMES_E_C", 1, p__QVar_E_Plus);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__QVar_E_Plus);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__QVar_E_Plus);}
};
class _O_QVar_E_Plus_Or_QGT_TIMES_E_C_rule1 : public _O_QVar_E_Plus_Or_QGT_TIMES_E_C {
private:
    GT_TIMES* m_GT_TIMES;
public:
    _O_QVar_E_Plus_Or_QGT_TIMES_E_C_rule1 (GT_TIMES* p_GT_TIMES) {
	m_GT_TIMES = p_GT_TIMES;
	trace("_O_QVar_E_Plus_Or_QGT_TIMES_E_C", 1, p_GT_TIMES);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GT_TIMES);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GT_TIMES);}
};
class _QDatasetClause_E_Star : public _GenProduction {
protected:
    _QDatasetClause_E_Star () : 
    _GenProduction("_QDatasetClause_E_Star", 0) {}
    _QDatasetClause_E_Star (DatasetClause* p_DatasetClause) : 
    _GenProduction("_QDatasetClause_E_Star", 1, p_DatasetClause) {}
    _QDatasetClause_E_Star (_QDatasetClause_E_Star* p__QDatasetClause_E_Star, DatasetClause* p_DatasetClause) : 
    _GenProduction("_QDatasetClause_E_Star", 2, p__QDatasetClause_E_Star, p_DatasetClause) {}
    virtual const char * getProductionName () { return "_QDatasetClause_E_Star"; }
};
class _QDatasetClause_E_Star_rule0 : public _QDatasetClause_E_Star {
public:
    _QDatasetClause_E_Star_rule0 () : 
    _QDatasetClause_E_Star() {
	trace("_QDatasetClause_E_Star", 0);
    }
};
class _QDatasetClause_E_Star_rule1 : public _QDatasetClause_E_Star {
public:
    _QDatasetClause_E_Star_rule1 (_QDatasetClause_E_Star* p__QDatasetClause_E_Star, DatasetClause* p_DatasetClause) : 
    _QDatasetClause_E_Star(p__QDatasetClause_E_Star, p_DatasetClause) {
	trace("_QDatasetClause_E_Star", 2, p__QDatasetClause_E_Star, p_DatasetClause);
	delete p__QDatasetClause_E_Star;
    }
};
class ConstructQuery : public _Production {
private:
    IT_CONSTRUCT* m_IT_CONSTRUCT;
    ConstructTemplate* m_ConstructTemplate;
    _QDatasetClause_E_Star* m__QDatasetClause_E_Star;
    WhereClause* m_WhereClause;
    SolutionModifier* m_SolutionModifier;
    virtual const char* getProductionName () { return "ConstructQuery"; }
public:
    ConstructQuery (IT_CONSTRUCT* p_IT_CONSTRUCT, ConstructTemplate* p_ConstructTemplate, _QDatasetClause_E_Star* p__QDatasetClause_E_Star, WhereClause* p_WhereClause, SolutionModifier* p_SolutionModifier) {
	m_IT_CONSTRUCT = p_IT_CONSTRUCT;
	m_ConstructTemplate = p_ConstructTemplate;
	m__QDatasetClause_E_Star = p__QDatasetClause_E_Star;
	m_WhereClause = p_WhereClause;
	m_SolutionModifier = p_SolutionModifier;
	trace("ConstructQuery", 5, p_IT_CONSTRUCT, p_ConstructTemplate, p__QDatasetClause_E_Star, p_WhereClause, p_SolutionModifier);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 5, m_IT_CONSTRUCT, m_ConstructTemplate, m__QDatasetClause_E_Star, m_WhereClause, m_SolutionModifier);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 5, m_IT_CONSTRUCT, m_ConstructTemplate, m__QDatasetClause_E_Star, m_WhereClause, m_SolutionModifier);}
};
class DescribeQuery : public _Production {
private:
    IT_DESCRIBE* m_IT_DESCRIBE;
    _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C* m__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C;
    _QDatasetClause_E_Star* m__QDatasetClause_E_Star;
    _QWhereClause_E_Opt* m__QWhereClause_E_Opt;
    SolutionModifier* m_SolutionModifier;
    virtual const char* getProductionName () { return "DescribeQuery"; }
public:
    DescribeQuery (IT_DESCRIBE* p_IT_DESCRIBE, _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C* p__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C, _QDatasetClause_E_Star* p__QDatasetClause_E_Star, _QWhereClause_E_Opt* p__QWhereClause_E_Opt, SolutionModifier* p_SolutionModifier) {
	m_IT_DESCRIBE = p_IT_DESCRIBE;
	m__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C = p__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C;
	m__QDatasetClause_E_Star = p__QDatasetClause_E_Star;
	m__QWhereClause_E_Opt = p__QWhereClause_E_Opt;
	m_SolutionModifier = p_SolutionModifier;
	trace("DescribeQuery", 5, p_IT_DESCRIBE, p__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C, p__QDatasetClause_E_Star, p__QWhereClause_E_Opt, p_SolutionModifier);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 5, m_IT_DESCRIBE, m__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C, m__QDatasetClause_E_Star, m__QWhereClause_E_Opt, m_SolutionModifier);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 5, m_IT_DESCRIBE, m__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C, m__QDatasetClause_E_Star, m__QWhereClause_E_Opt, m_SolutionModifier);}
};
class _QVarOrIRIref_E_Plus : public _GenProduction {
protected:
    _QVarOrIRIref_E_Plus () : 
    _GenProduction("_QVarOrIRIref_E_Plus", 0) {}
    _QVarOrIRIref_E_Plus (VarOrIRIref* p_VarOrIRIref) : 
    _GenProduction("_QVarOrIRIref_E_Plus", 1, p_VarOrIRIref) {}
    _QVarOrIRIref_E_Plus (_QVarOrIRIref_E_Plus* p__QVarOrIRIref_E_Plus, VarOrIRIref* p_VarOrIRIref) : 
    _GenProduction("_QVarOrIRIref_E_Plus", 2, p__QVarOrIRIref_E_Plus, p_VarOrIRIref) {}
    virtual const char * getProductionName () { return "_QVarOrIRIref_E_Plus"; }
};
class _QVarOrIRIref_E_Plus_rule0 : public _QVarOrIRIref_E_Plus {
public:
    _QVarOrIRIref_E_Plus_rule0 (VarOrIRIref* p_VarOrIRIref) : 
    _QVarOrIRIref_E_Plus(p_VarOrIRIref) {
	trace("_QVarOrIRIref_E_Plus", 1, p_VarOrIRIref);
    }
};
class _QVarOrIRIref_E_Plus_rule1 : public _QVarOrIRIref_E_Plus {
public:
    _QVarOrIRIref_E_Plus_rule1 (_QVarOrIRIref_E_Plus* p__QVarOrIRIref_E_Plus, VarOrIRIref* p_VarOrIRIref) : 
    _QVarOrIRIref_E_Plus(p__QVarOrIRIref_E_Plus, p_VarOrIRIref) {
	trace("_QVarOrIRIref_E_Plus", 2, p__QVarOrIRIref_E_Plus, p_VarOrIRIref);
	delete p__QVarOrIRIref_E_Plus;
    }
};
class _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C"; }
};
class _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C_rule0 : public _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C {
private:
    _QVarOrIRIref_E_Plus* m__QVarOrIRIref_E_Plus;
public:
    _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C_rule0 (_QVarOrIRIref_E_Plus* p__QVarOrIRIref_E_Plus) {
	m__QVarOrIRIref_E_Plus = p__QVarOrIRIref_E_Plus;
	trace("_O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C", 1, p__QVarOrIRIref_E_Plus);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__QVarOrIRIref_E_Plus);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__QVarOrIRIref_E_Plus);}
};
class _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C_rule1 : public _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C {
private:
    GT_TIMES* m_GT_TIMES;
public:
    _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C_rule1 (GT_TIMES* p_GT_TIMES) {
	m_GT_TIMES = p_GT_TIMES;
	trace("_O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C", 1, p_GT_TIMES);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GT_TIMES);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GT_TIMES);}
};
class _QWhereClause_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QWhereClause_E_Opt"; }
};
class _QWhereClause_E_Opt_rule0 : public _QWhereClause_E_Opt {
public:
    _QWhereClause_E_Opt_rule0 () {
	trace("_QWhereClause_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QWhereClause_E_Opt_rule1 : public _QWhereClause_E_Opt {
private:
    WhereClause* m_WhereClause;
public:
    _QWhereClause_E_Opt_rule1 (WhereClause* p_WhereClause) {
	m_WhereClause = p_WhereClause;
	trace("_QWhereClause_E_Opt", 1, p_WhereClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_WhereClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_WhereClause);}
};
class AskQuery : public _Production {
private:
    IT_ASK* m_IT_ASK;
    _QDatasetClause_E_Star* m__QDatasetClause_E_Star;
    WhereClause* m_WhereClause;
    virtual const char* getProductionName () { return "AskQuery"; }
public:
    AskQuery (IT_ASK* p_IT_ASK, _QDatasetClause_E_Star* p__QDatasetClause_E_Star, WhereClause* p_WhereClause) {
	m_IT_ASK = p_IT_ASK;
	m__QDatasetClause_E_Star = p__QDatasetClause_E_Star;
	m_WhereClause = p_WhereClause;
	trace("AskQuery", 3, p_IT_ASK, p__QDatasetClause_E_Star, p_WhereClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_IT_ASK, m__QDatasetClause_E_Star, m_WhereClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_IT_ASK, m__QDatasetClause_E_Star, m_WhereClause);}
};
class DatasetClause : public _Production {
private:
    IT_FROM* m_IT_FROM;
    _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C* m__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C;
    virtual const char* getProductionName () { return "DatasetClause"; }
public:
    DatasetClause (IT_FROM* p_IT_FROM, _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C* p__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C) {
	m_IT_FROM = p_IT_FROM;
	m__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C = p__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C;
	trace("DatasetClause", 2, p_IT_FROM, p__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_FROM, m__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_FROM, m__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C);}
};
class _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C"; }
};
class _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C_rule0 : public _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C {
private:
    DefaultGraphClause* m_DefaultGraphClause;
public:
    _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C_rule0 (DefaultGraphClause* p_DefaultGraphClause) {
	m_DefaultGraphClause = p_DefaultGraphClause;
	trace("_O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C", 1, p_DefaultGraphClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DefaultGraphClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DefaultGraphClause);}
};
class _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C_rule1 : public _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C {
private:
    NamedGraphClause* m_NamedGraphClause;
public:
    _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C_rule1 (NamedGraphClause* p_NamedGraphClause) {
	m_NamedGraphClause = p_NamedGraphClause;
	trace("_O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C", 1, p_NamedGraphClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NamedGraphClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NamedGraphClause);}
};
class DefaultGraphClause : public _Production {
private:
    SourceSelector* m_SourceSelector;
    virtual const char* getProductionName () { return "DefaultGraphClause"; }
public:
    DefaultGraphClause (SourceSelector* p_SourceSelector) {
	m_SourceSelector = p_SourceSelector;
	trace("DefaultGraphClause", 1, p_SourceSelector);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_SourceSelector);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_SourceSelector);}
};
class NamedGraphClause : public _Production {
private:
    IT_NAMED* m_IT_NAMED;
    SourceSelector* m_SourceSelector;
    virtual const char* getProductionName () { return "NamedGraphClause"; }
public:
    NamedGraphClause (IT_NAMED* p_IT_NAMED, SourceSelector* p_SourceSelector) {
	m_IT_NAMED = p_IT_NAMED;
	m_SourceSelector = p_SourceSelector;
	trace("NamedGraphClause", 2, p_IT_NAMED, p_SourceSelector);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_NAMED, m_SourceSelector);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_NAMED, m_SourceSelector);}
};
class SourceSelector : public _Production {
private:
    IRIref* m_IRIref;
    virtual const char* getProductionName () { return "SourceSelector"; }
public:
    SourceSelector (IRIref* p_IRIref) {
	m_IRIref = p_IRIref;
	trace("SourceSelector", 1, p_IRIref);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IRIref);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IRIref);}
};
class WhereClause : public _Production {
private:
    _QIT_WHERE_E_Opt* m__QIT_WHERE_E_Opt;
    GroupGraphPattern* m_GroupGraphPattern;
    virtual const char* getProductionName () { return "WhereClause"; }
public:
    WhereClause (_QIT_WHERE_E_Opt* p__QIT_WHERE_E_Opt, GroupGraphPattern* p_GroupGraphPattern) {
	m__QIT_WHERE_E_Opt = p__QIT_WHERE_E_Opt;
	m_GroupGraphPattern = p_GroupGraphPattern;
	trace("WhereClause", 2, p__QIT_WHERE_E_Opt, p_GroupGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m__QIT_WHERE_E_Opt, m_GroupGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m__QIT_WHERE_E_Opt, m_GroupGraphPattern);}
};
class _QIT_WHERE_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QIT_WHERE_E_Opt"; }
};
class _QIT_WHERE_E_Opt_rule0 : public _QIT_WHERE_E_Opt {
public:
    _QIT_WHERE_E_Opt_rule0 () {
	trace("_QIT_WHERE_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QIT_WHERE_E_Opt_rule1 : public _QIT_WHERE_E_Opt {
private:
    IT_WHERE* m_IT_WHERE;
public:
    _QIT_WHERE_E_Opt_rule1 (IT_WHERE* p_IT_WHERE) {
	m_IT_WHERE = p_IT_WHERE;
	trace("_QIT_WHERE_E_Opt", 1, p_IT_WHERE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_WHERE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_WHERE);}
};
class SolutionModifier : public _Production {
private:
    _QOrderClause_E_Opt* m__QOrderClause_E_Opt;
    _QLimitOffsetClauses_E_Opt* m__QLimitOffsetClauses_E_Opt;
    virtual const char* getProductionName () { return "SolutionModifier"; }
public:
    SolutionModifier (_QOrderClause_E_Opt* p__QOrderClause_E_Opt, _QLimitOffsetClauses_E_Opt* p__QLimitOffsetClauses_E_Opt) {
	m__QOrderClause_E_Opt = p__QOrderClause_E_Opt;
	m__QLimitOffsetClauses_E_Opt = p__QLimitOffsetClauses_E_Opt;
	trace("SolutionModifier", 2, p__QOrderClause_E_Opt, p__QLimitOffsetClauses_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m__QOrderClause_E_Opt, m__QLimitOffsetClauses_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m__QOrderClause_E_Opt, m__QLimitOffsetClauses_E_Opt);}
};
class _QOrderClause_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QOrderClause_E_Opt"; }
};
class _QOrderClause_E_Opt_rule0 : public _QOrderClause_E_Opt {
public:
    _QOrderClause_E_Opt_rule0 () {
	trace("_QOrderClause_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QOrderClause_E_Opt_rule1 : public _QOrderClause_E_Opt {
private:
    OrderClause* m_OrderClause;
public:
    _QOrderClause_E_Opt_rule1 (OrderClause* p_OrderClause) {
	m_OrderClause = p_OrderClause;
	trace("_QOrderClause_E_Opt", 1, p_OrderClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_OrderClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_OrderClause);}
};
class _QLimitOffsetClauses_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QLimitOffsetClauses_E_Opt"; }
};
class _QLimitOffsetClauses_E_Opt_rule0 : public _QLimitOffsetClauses_E_Opt {
public:
    _QLimitOffsetClauses_E_Opt_rule0 () {
	trace("_QLimitOffsetClauses_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QLimitOffsetClauses_E_Opt_rule1 : public _QLimitOffsetClauses_E_Opt {
private:
    LimitOffsetClauses* m_LimitOffsetClauses;
public:
    _QLimitOffsetClauses_E_Opt_rule1 (LimitOffsetClauses* p_LimitOffsetClauses) {
	m_LimitOffsetClauses = p_LimitOffsetClauses;
	trace("_QLimitOffsetClauses_E_Opt", 1, p_LimitOffsetClauses);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_LimitOffsetClauses);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_LimitOffsetClauses);}
};
class LimitOffsetClauses : public _Production {
private:
    _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C* m__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C;
    virtual const char* getProductionName () { return "LimitOffsetClauses"; }
public:
    LimitOffsetClauses (_O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C* p__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C) {
	m__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C = p__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C;
	trace("LimitOffsetClauses", 1, p__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C);}
};
class _QOffsetClause_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QOffsetClause_E_Opt"; }
};
class _QOffsetClause_E_Opt_rule0 : public _QOffsetClause_E_Opt {
public:
    _QOffsetClause_E_Opt_rule0 () {
	trace("_QOffsetClause_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QOffsetClause_E_Opt_rule1 : public _QOffsetClause_E_Opt {
private:
    OffsetClause* m_OffsetClause;
public:
    _QOffsetClause_E_Opt_rule1 (OffsetClause* p_OffsetClause) {
	m_OffsetClause = p_OffsetClause;
	trace("_QOffsetClause_E_Opt", 1, p_OffsetClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_OffsetClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_OffsetClause);}
};
class _QLimitClause_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QLimitClause_E_Opt"; }
};
class _QLimitClause_E_Opt_rule0 : public _QLimitClause_E_Opt {
public:
    _QLimitClause_E_Opt_rule0 () {
	trace("_QLimitClause_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QLimitClause_E_Opt_rule1 : public _QLimitClause_E_Opt {
private:
    LimitClause* m_LimitClause;
public:
    _QLimitClause_E_Opt_rule1 (LimitClause* p_LimitClause) {
	m_LimitClause = p_LimitClause;
	trace("_QLimitClause_E_Opt", 1, p_LimitClause);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_LimitClause);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_LimitClause);}
};
class _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C"; }
};
class _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C_rule0 : public _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C {
private:
    LimitClause* m_LimitClause;
    _QOffsetClause_E_Opt* m__QOffsetClause_E_Opt;
public:
    _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C_rule0 (LimitClause* p_LimitClause, _QOffsetClause_E_Opt* p__QOffsetClause_E_Opt) {
	m_LimitClause = p_LimitClause;
	m__QOffsetClause_E_Opt = p__QOffsetClause_E_Opt;
	trace("_O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C", 2, p_LimitClause, p__QOffsetClause_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_LimitClause, m__QOffsetClause_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_LimitClause, m__QOffsetClause_E_Opt);}
};
class _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C_rule1 : public _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C {
private:
    OffsetClause* m_OffsetClause;
    _QLimitClause_E_Opt* m__QLimitClause_E_Opt;
public:
    _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C_rule1 (OffsetClause* p_OffsetClause, _QLimitClause_E_Opt* p__QLimitClause_E_Opt) {
	m_OffsetClause = p_OffsetClause;
	m__QLimitClause_E_Opt = p__QLimitClause_E_Opt;
	trace("_O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C", 2, p_OffsetClause, p__QLimitClause_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_OffsetClause, m__QLimitClause_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_OffsetClause, m__QLimitClause_E_Opt);}
};
class OrderClause : public _Production {
private:
    IT_ORDER* m_IT_ORDER;
    IT_BY* m_IT_BY;
    _QOrderCondition_E_Plus* m__QOrderCondition_E_Plus;
    virtual const char* getProductionName () { return "OrderClause"; }
public:
    OrderClause (IT_ORDER* p_IT_ORDER, IT_BY* p_IT_BY, _QOrderCondition_E_Plus* p__QOrderCondition_E_Plus) {
	m_IT_ORDER = p_IT_ORDER;
	m_IT_BY = p_IT_BY;
	m__QOrderCondition_E_Plus = p__QOrderCondition_E_Plus;
	trace("OrderClause", 3, p_IT_ORDER, p_IT_BY, p__QOrderCondition_E_Plus);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_IT_ORDER, m_IT_BY, m__QOrderCondition_E_Plus);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_IT_ORDER, m_IT_BY, m__QOrderCondition_E_Plus);}
};
class _QOrderCondition_E_Plus : public _GenProduction {
protected:
    _QOrderCondition_E_Plus () : 
    _GenProduction("_QOrderCondition_E_Plus", 0) {}
    _QOrderCondition_E_Plus (OrderCondition* p_OrderCondition) : 
    _GenProduction("_QOrderCondition_E_Plus", 1, p_OrderCondition) {}
    _QOrderCondition_E_Plus (_QOrderCondition_E_Plus* p__QOrderCondition_E_Plus, OrderCondition* p_OrderCondition) : 
    _GenProduction("_QOrderCondition_E_Plus", 2, p__QOrderCondition_E_Plus, p_OrderCondition) {}
    virtual const char * getProductionName () { return "_QOrderCondition_E_Plus"; }
};
class _QOrderCondition_E_Plus_rule0 : public _QOrderCondition_E_Plus {
public:
    _QOrderCondition_E_Plus_rule0 (OrderCondition* p_OrderCondition) : 
    _QOrderCondition_E_Plus(p_OrderCondition) {
	trace("_QOrderCondition_E_Plus", 1, p_OrderCondition);
    }
};
class _QOrderCondition_E_Plus_rule1 : public _QOrderCondition_E_Plus {
public:
    _QOrderCondition_E_Plus_rule1 (_QOrderCondition_E_Plus* p__QOrderCondition_E_Plus, OrderCondition* p_OrderCondition) : 
    _QOrderCondition_E_Plus(p__QOrderCondition_E_Plus, p_OrderCondition) {
	trace("_QOrderCondition_E_Plus", 2, p__QOrderCondition_E_Plus, p_OrderCondition);
	delete p__QOrderCondition_E_Plus;
    }
};
class OrderCondition : public _Production {
private:
    virtual const char * getProductionName () { return "OrderCondition"; }
};
class OrderCondition_rule0 : public OrderCondition {
private:
    _O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C* m__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C;
public:
    OrderCondition_rule0 (_O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C* p__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C) {
	m__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C = p__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C;
	trace("OrderCondition", 1, p__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C);}
};
class OrderCondition_rule1 : public OrderCondition {
private:
    _O_QConstraint_E_Or_QVar_E_C* m__O_QConstraint_E_Or_QVar_E_C;
public:
    OrderCondition_rule1 (_O_QConstraint_E_Or_QVar_E_C* p__O_QConstraint_E_Or_QVar_E_C) {
	m__O_QConstraint_E_Or_QVar_E_C = p__O_QConstraint_E_Or_QVar_E_C;
	trace("OrderCondition", 1, p__O_QConstraint_E_Or_QVar_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QConstraint_E_Or_QVar_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QConstraint_E_Or_QVar_E_C);}
};
class _O_QIT_ASC_E_Or_QIT_DESC_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QIT_ASC_E_Or_QIT_DESC_E_C"; }
};
class _O_QIT_ASC_E_Or_QIT_DESC_E_C_rule0 : public _O_QIT_ASC_E_Or_QIT_DESC_E_C {
private:
    IT_ASC* m_IT_ASC;
public:
    _O_QIT_ASC_E_Or_QIT_DESC_E_C_rule0 (IT_ASC* p_IT_ASC) {
	m_IT_ASC = p_IT_ASC;
	trace("_O_QIT_ASC_E_Or_QIT_DESC_E_C", 1, p_IT_ASC);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_ASC);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_ASC);}
};
class _O_QIT_ASC_E_Or_QIT_DESC_E_C_rule1 : public _O_QIT_ASC_E_Or_QIT_DESC_E_C {
private:
    IT_DESC* m_IT_DESC;
public:
    _O_QIT_ASC_E_Or_QIT_DESC_E_C_rule1 (IT_DESC* p_IT_DESC) {
	m_IT_DESC = p_IT_DESC;
	trace("_O_QIT_ASC_E_Or_QIT_DESC_E_C", 1, p_IT_DESC);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_DESC);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_DESC);}
};
class _O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C : public _Production {
private:
    _O_QIT_ASC_E_Or_QIT_DESC_E_C* m__O_QIT_ASC_E_Or_QIT_DESC_E_C;
    BrackettedExpression* m_BrackettedExpression;
    virtual const char* getProductionName () { return "_O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C"; }
public:
    _O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C (_O_QIT_ASC_E_Or_QIT_DESC_E_C* p__O_QIT_ASC_E_Or_QIT_DESC_E_C, BrackettedExpression* p_BrackettedExpression) {
	m__O_QIT_ASC_E_Or_QIT_DESC_E_C = p__O_QIT_ASC_E_Or_QIT_DESC_E_C;
	m_BrackettedExpression = p_BrackettedExpression;
	trace("_O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C", 2, p__O_QIT_ASC_E_Or_QIT_DESC_E_C, p_BrackettedExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m__O_QIT_ASC_E_Or_QIT_DESC_E_C, m_BrackettedExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m__O_QIT_ASC_E_Or_QIT_DESC_E_C, m_BrackettedExpression);}
};
class _O_QConstraint_E_Or_QVar_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QConstraint_E_Or_QVar_E_C"; }
};
class _O_QConstraint_E_Or_QVar_E_C_rule0 : public _O_QConstraint_E_Or_QVar_E_C {
private:
    Constraint* m_Constraint;
public:
    _O_QConstraint_E_Or_QVar_E_C_rule0 (Constraint* p_Constraint) {
	m_Constraint = p_Constraint;
	trace("_O_QConstraint_E_Or_QVar_E_C", 1, p_Constraint);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Constraint);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Constraint);}
};
class _O_QConstraint_E_Or_QVar_E_C_rule1 : public _O_QConstraint_E_Or_QVar_E_C {
private:
    Var* m_Var;
public:
    _O_QConstraint_E_Or_QVar_E_C_rule1 (Var* p_Var) {
	m_Var = p_Var;
	trace("_O_QConstraint_E_Or_QVar_E_C", 1, p_Var);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Var);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Var);}
};
class LimitClause : public _Production {
private:
    IT_LIMIT* m_IT_LIMIT;
    INTEGER* m_INTEGER;
    virtual const char* getProductionName () { return "LimitClause"; }
public:
    LimitClause (IT_LIMIT* p_IT_LIMIT, INTEGER* p_INTEGER) {
	m_IT_LIMIT = p_IT_LIMIT;
	m_INTEGER = p_INTEGER;
	trace("LimitClause", 2, p_IT_LIMIT, p_INTEGER);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_LIMIT, m_INTEGER);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_LIMIT, m_INTEGER);}
};
class OffsetClause : public _Production {
private:
    IT_OFFSET* m_IT_OFFSET;
    INTEGER* m_INTEGER;
    virtual const char* getProductionName () { return "OffsetClause"; }
public:
    OffsetClause (IT_OFFSET* p_IT_OFFSET, INTEGER* p_INTEGER) {
	m_IT_OFFSET = p_IT_OFFSET;
	m_INTEGER = p_INTEGER;
	trace("OffsetClause", 2, p_IT_OFFSET, p_INTEGER);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_OFFSET, m_INTEGER);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_OFFSET, m_INTEGER);}
};
class GroupGraphPattern : public _Production {
private:
    GT_LCURLEY* m_GT_LCURLEY;
    _QTriplesBlock_E_Opt* m__QTriplesBlock_E_Opt;
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star* m__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star;
    GT_RCURLEY* m_GT_RCURLEY;
    virtual const char* getProductionName () { return "GroupGraphPattern"; }
public:
    GroupGraphPattern (GT_LCURLEY* p_GT_LCURLEY, _QTriplesBlock_E_Opt* p__QTriplesBlock_E_Opt, _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star* p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, GT_RCURLEY* p_GT_RCURLEY) {
	m_GT_LCURLEY = p_GT_LCURLEY;
	m__QTriplesBlock_E_Opt = p__QTriplesBlock_E_Opt;
	m__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star = p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star;
	m_GT_RCURLEY = p_GT_RCURLEY;
	trace("GroupGraphPattern", 4, p_GT_LCURLEY, p__QTriplesBlock_E_Opt, p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, p_GT_RCURLEY);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_GT_LCURLEY, m__QTriplesBlock_E_Opt, m__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, m_GT_RCURLEY);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_GT_LCURLEY, m__QTriplesBlock_E_Opt, m__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, m_GT_RCURLEY);}
};
class _QTriplesBlock_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QTriplesBlock_E_Opt"; }
};
class _QTriplesBlock_E_Opt_rule0 : public _QTriplesBlock_E_Opt {
public:
    _QTriplesBlock_E_Opt_rule0 () {
	trace("_QTriplesBlock_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QTriplesBlock_E_Opt_rule1 : public _QTriplesBlock_E_Opt {
private:
    TriplesBlock* m_TriplesBlock;
public:
    _QTriplesBlock_E_Opt_rule1 (TriplesBlock* p_TriplesBlock) {
	m_TriplesBlock = p_TriplesBlock;
	trace("_QTriplesBlock_E_Opt", 1, p_TriplesBlock);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_TriplesBlock);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_TriplesBlock);}
};
class _O_QGraphPatternNotTriples_E_Or_QFilter_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QGraphPatternNotTriples_E_Or_QFilter_E_C"; }
};
class _O_QGraphPatternNotTriples_E_Or_QFilter_E_C_rule0 : public _O_QGraphPatternNotTriples_E_Or_QFilter_E_C {
private:
    GraphPatternNotTriples* m_GraphPatternNotTriples;
public:
    _O_QGraphPatternNotTriples_E_Or_QFilter_E_C_rule0 (GraphPatternNotTriples* p_GraphPatternNotTriples) {
	m_GraphPatternNotTriples = p_GraphPatternNotTriples;
	trace("_O_QGraphPatternNotTriples_E_Or_QFilter_E_C", 1, p_GraphPatternNotTriples);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GraphPatternNotTriples);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GraphPatternNotTriples);}
};
class _O_QGraphPatternNotTriples_E_Or_QFilter_E_C_rule1 : public _O_QGraphPatternNotTriples_E_Or_QFilter_E_C {
private:
    Filter* m_Filter;
public:
    _O_QGraphPatternNotTriples_E_Or_QFilter_E_C_rule1 (Filter* p_Filter) {
	m_Filter = p_Filter;
	trace("_O_QGraphPatternNotTriples_E_Or_QFilter_E_C", 1, p_Filter);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Filter);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Filter);}
};
class _QGT_DOT_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QGT_DOT_E_Opt"; }
};
class _QGT_DOT_E_Opt_rule0 : public _QGT_DOT_E_Opt {
public:
    _QGT_DOT_E_Opt_rule0 () {
	trace("_QGT_DOT_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QGT_DOT_E_Opt_rule1 : public _QGT_DOT_E_Opt {
private:
    GT_DOT* m_GT_DOT;
public:
    _QGT_DOT_E_Opt_rule1 (GT_DOT* p_GT_DOT) {
	m_GT_DOT = p_GT_DOT;
	trace("_QGT_DOT_E_Opt", 1, p_GT_DOT);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GT_DOT);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GT_DOT);}
};
class _O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C : public _Production {
private:
    _O_QGraphPatternNotTriples_E_Or_QFilter_E_C* m__O_QGraphPatternNotTriples_E_Or_QFilter_E_C;
    _QGT_DOT_E_Opt* m__QGT_DOT_E_Opt;
    _QTriplesBlock_E_Opt* m__QTriplesBlock_E_Opt;
    virtual const char* getProductionName () { return "_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C"; }
public:
    _O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C (_O_QGraphPatternNotTriples_E_Or_QFilter_E_C* p__O_QGraphPatternNotTriples_E_Or_QFilter_E_C, _QGT_DOT_E_Opt* p__QGT_DOT_E_Opt, _QTriplesBlock_E_Opt* p__QTriplesBlock_E_Opt) {
	m__O_QGraphPatternNotTriples_E_Or_QFilter_E_C = p__O_QGraphPatternNotTriples_E_Or_QFilter_E_C;
	m__QGT_DOT_E_Opt = p__QGT_DOT_E_Opt;
	m__QTriplesBlock_E_Opt = p__QTriplesBlock_E_Opt;
	trace("_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C", 3, p__O_QGraphPatternNotTriples_E_Or_QFilter_E_C, p__QGT_DOT_E_Opt, p__QTriplesBlock_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m__O_QGraphPatternNotTriples_E_Or_QFilter_E_C, m__QGT_DOT_E_Opt, m__QTriplesBlock_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m__O_QGraphPatternNotTriples_E_Or_QFilter_E_C, m__QGT_DOT_E_Opt, m__QTriplesBlock_E_Opt);}
};
class _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star () : 
    _GenProduction("_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star", 0) {}
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star (_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C* p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C) : 
    _GenProduction("_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star", 1, p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C) {}
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star (_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star* p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, _O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C* p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C) : 
    _GenProduction("_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star", 2, p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star"; }
};
class _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star_rule0 : public _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star {
public:
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star_rule0 () : 
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star() {
	trace("_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star", 0);
    }
};
class _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star_rule1 : public _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star {
public:
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star_rule1 (_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star* p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, _O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C* p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C) : 
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star(p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C) {
	trace("_Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star", 2, p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star, p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C);
	delete p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star;
    }
};
class TriplesBlock : public _Production {
private:
    TriplesSameSubject* m_TriplesSameSubject;
    _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt* m__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt;
    virtual const char* getProductionName () { return "TriplesBlock"; }
public:
    TriplesBlock (TriplesSameSubject* p_TriplesSameSubject, _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt* p__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt) {
	m_TriplesSameSubject = p_TriplesSameSubject;
	m__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt = p__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt;
	trace("TriplesBlock", 2, p_TriplesSameSubject, p__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_TriplesSameSubject, m__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_TriplesSameSubject, m__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt);}
};
class _O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C : public _Production {
private:
    GT_DOT* m_GT_DOT;
    _QTriplesBlock_E_Opt* m__QTriplesBlock_E_Opt;
    virtual const char* getProductionName () { return "_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C"; }
public:
    _O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C (GT_DOT* p_GT_DOT, _QTriplesBlock_E_Opt* p__QTriplesBlock_E_Opt) {
	m_GT_DOT = p_GT_DOT;
	m__QTriplesBlock_E_Opt = p__QTriplesBlock_E_Opt;
	trace("_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C", 2, p_GT_DOT, p__QTriplesBlock_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_DOT, m__QTriplesBlock_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_DOT, m__QTriplesBlock_E_Opt);}
};
class _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt"; }
};
class _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt_rule0 : public _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt {
public:
    _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt_rule0 () {
	trace("_Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt_rule1 : public _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt {
private:
    _O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C* m__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C;
public:
    _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt_rule1 (_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C* p__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C) {
	m__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C = p__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C;
	trace("_Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt", 1, p__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C);}
};
class GraphPatternNotTriples : public _Production {
private:
    virtual const char * getProductionName () { return "GraphPatternNotTriples"; }
};
class GraphPatternNotTriples_rule0 : public GraphPatternNotTriples {
private:
    OptionalGraphPattern* m_OptionalGraphPattern;
public:
    GraphPatternNotTriples_rule0 (OptionalGraphPattern* p_OptionalGraphPattern) {
	m_OptionalGraphPattern = p_OptionalGraphPattern;
	trace("GraphPatternNotTriples", 1, p_OptionalGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_OptionalGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_OptionalGraphPattern);}
};
class GraphPatternNotTriples_rule1 : public GraphPatternNotTriples {
private:
    GroupOrUnionGraphPattern* m_GroupOrUnionGraphPattern;
public:
    GraphPatternNotTriples_rule1 (GroupOrUnionGraphPattern* p_GroupOrUnionGraphPattern) {
	m_GroupOrUnionGraphPattern = p_GroupOrUnionGraphPattern;
	trace("GraphPatternNotTriples", 1, p_GroupOrUnionGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GroupOrUnionGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GroupOrUnionGraphPattern);}
};
class GraphPatternNotTriples_rule2 : public GraphPatternNotTriples {
private:
    GraphGraphPattern* m_GraphGraphPattern;
public:
    GraphPatternNotTriples_rule2 (GraphGraphPattern* p_GraphGraphPattern) {
	m_GraphGraphPattern = p_GraphGraphPattern;
	trace("GraphPatternNotTriples", 1, p_GraphGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GraphGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GraphGraphPattern);}
};
class OptionalGraphPattern : public _Production {
private:
    IT_OPTIONAL* m_IT_OPTIONAL;
    GroupGraphPattern* m_GroupGraphPattern;
    virtual const char* getProductionName () { return "OptionalGraphPattern"; }
public:
    OptionalGraphPattern (IT_OPTIONAL* p_IT_OPTIONAL, GroupGraphPattern* p_GroupGraphPattern) {
	m_IT_OPTIONAL = p_IT_OPTIONAL;
	m_GroupGraphPattern = p_GroupGraphPattern;
	trace("OptionalGraphPattern", 2, p_IT_OPTIONAL, p_GroupGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_OPTIONAL, m_GroupGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_OPTIONAL, m_GroupGraphPattern);}
};
class GraphGraphPattern : public _Production {
private:
    IT_GRAPH* m_IT_GRAPH;
    VarOrIRIref* m_VarOrIRIref;
    GroupGraphPattern* m_GroupGraphPattern;
    virtual const char* getProductionName () { return "GraphGraphPattern"; }
public:
    GraphGraphPattern (IT_GRAPH* p_IT_GRAPH, VarOrIRIref* p_VarOrIRIref, GroupGraphPattern* p_GroupGraphPattern) {
	m_IT_GRAPH = p_IT_GRAPH;
	m_VarOrIRIref = p_VarOrIRIref;
	m_GroupGraphPattern = p_GroupGraphPattern;
	trace("GraphGraphPattern", 3, p_IT_GRAPH, p_VarOrIRIref, p_GroupGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_IT_GRAPH, m_VarOrIRIref, m_GroupGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_IT_GRAPH, m_VarOrIRIref, m_GroupGraphPattern);}
};
class GroupOrUnionGraphPattern : public _Production {
private:
    GroupGraphPattern* m_GroupGraphPattern;
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star* m__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star;
    virtual const char* getProductionName () { return "GroupOrUnionGraphPattern"; }
public:
    GroupOrUnionGraphPattern (GroupGraphPattern* p_GroupGraphPattern, _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star* p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star) {
	m_GroupGraphPattern = p_GroupGraphPattern;
	m__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star = p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star;
	trace("GroupOrUnionGraphPattern", 2, p_GroupGraphPattern, p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GroupGraphPattern, m__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GroupGraphPattern, m__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star);}
};
class _O_QIT_UNION_E_S_QGroupGraphPattern_E_C : public _Production {
private:
    IT_UNION* m_IT_UNION;
    GroupGraphPattern* m_GroupGraphPattern;
    virtual const char* getProductionName () { return "_O_QIT_UNION_E_S_QGroupGraphPattern_E_C"; }
public:
    _O_QIT_UNION_E_S_QGroupGraphPattern_E_C (IT_UNION* p_IT_UNION, GroupGraphPattern* p_GroupGraphPattern) {
	m_IT_UNION = p_IT_UNION;
	m_GroupGraphPattern = p_GroupGraphPattern;
	trace("_O_QIT_UNION_E_S_QGroupGraphPattern_E_C", 2, p_IT_UNION, p_GroupGraphPattern);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_UNION, m_GroupGraphPattern);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_UNION, m_GroupGraphPattern);}
};
class _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star () : 
    _GenProduction("_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star", 0) {}
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star (_O_QIT_UNION_E_S_QGroupGraphPattern_E_C* p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C) : 
    _GenProduction("_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star", 1, p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C) {}
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star (_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star* p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star, _O_QIT_UNION_E_S_QGroupGraphPattern_E_C* p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C) : 
    _GenProduction("_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star", 2, p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star, p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star"; }
};
class _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star_rule0 : public _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star {
public:
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star_rule0 () : 
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star() {
	trace("_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star", 0);
    }
};
class _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star_rule1 : public _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star {
public:
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star_rule1 (_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star* p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star, _O_QIT_UNION_E_S_QGroupGraphPattern_E_C* p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C) : 
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star(p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star, p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C) {
	trace("_Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star", 2, p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star, p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C);
	delete p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star;
    }
};
class Filter : public _Production {
private:
    IT_FILTER* m_IT_FILTER;
    Constraint* m_Constraint;
    virtual const char* getProductionName () { return "Filter"; }
public:
    Filter (IT_FILTER* p_IT_FILTER, Constraint* p_Constraint) {
	m_IT_FILTER = p_IT_FILTER;
	m_Constraint = p_Constraint;
	trace("Filter", 2, p_IT_FILTER, p_Constraint);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IT_FILTER, m_Constraint);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IT_FILTER, m_Constraint);}
};
class Constraint : public _Production {
private:
    virtual const char * getProductionName () { return "Constraint"; }
};
class Constraint_rule0 : public Constraint {
private:
    BrackettedExpression* m_BrackettedExpression;
public:
    Constraint_rule0 (BrackettedExpression* p_BrackettedExpression) {
	m_BrackettedExpression = p_BrackettedExpression;
	trace("Constraint", 1, p_BrackettedExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BrackettedExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BrackettedExpression);}
};
class Constraint_rule1 : public Constraint {
private:
    BuiltInCall* m_BuiltInCall;
public:
    Constraint_rule1 (BuiltInCall* p_BuiltInCall) {
	m_BuiltInCall = p_BuiltInCall;
	trace("Constraint", 1, p_BuiltInCall);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BuiltInCall);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BuiltInCall);}
};
class Constraint_rule2 : public Constraint {
private:
    FunctionCall* m_FunctionCall;
public:
    Constraint_rule2 (FunctionCall* p_FunctionCall) {
	m_FunctionCall = p_FunctionCall;
	trace("Constraint", 1, p_FunctionCall);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_FunctionCall);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_FunctionCall);}
};
class FunctionCall : public _Production {
private:
    IRIref* m_IRIref;
    ArgList* m_ArgList;
    virtual const char* getProductionName () { return "FunctionCall"; }
public:
    FunctionCall (IRIref* p_IRIref, ArgList* p_ArgList) {
	m_IRIref = p_IRIref;
	m_ArgList = p_ArgList;
	trace("FunctionCall", 2, p_IRIref, p_ArgList);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IRIref, m_ArgList);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IRIref, m_ArgList);}
};
class ArgList : public _Production {
private:
    _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C* m__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C;
    virtual const char* getProductionName () { return "ArgList"; }
public:
    ArgList (_O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C* p__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C) {
	m__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C = p__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C;
	trace("ArgList", 1, p__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C);}
};
class _O_QGT_COMMA_E_S_QExpression_E_C : public _Production {
private:
    GT_COMMA* m_GT_COMMA;
    Expression* m_Expression;
    virtual const char* getProductionName () { return "_O_QGT_COMMA_E_S_QExpression_E_C"; }
public:
    _O_QGT_COMMA_E_S_QExpression_E_C (GT_COMMA* p_GT_COMMA, Expression* p_Expression) {
	m_GT_COMMA = p_GT_COMMA;
	m_Expression = p_Expression;
	trace("_O_QGT_COMMA_E_S_QExpression_E_C", 2, p_GT_COMMA, p_Expression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_COMMA, m_Expression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_COMMA, m_Expression);}
};
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star () : 
    _GenProduction("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star", 0) {}
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star (_O_QGT_COMMA_E_S_QExpression_E_C* p__O_QGT_COMMA_E_S_QExpression_E_C) : 
    _GenProduction("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star", 1, p__O_QGT_COMMA_E_S_QExpression_E_C) {}
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star (_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, _O_QGT_COMMA_E_S_QExpression_E_C* p__O_QGT_COMMA_E_S_QExpression_E_C) : 
    _GenProduction("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star", 2, p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, p__O_QGT_COMMA_E_S_QExpression_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star"; }
};
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star_rule0 : public _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star {
public:
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star_rule0 () : 
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star() {
	trace("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star", 0);
    }
};
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star_rule1 : public _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star {
public:
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star_rule1 (_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, _O_QGT_COMMA_E_S_QExpression_E_C* p__O_QGT_COMMA_E_S_QExpression_E_C) : 
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star(p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, p__O_QGT_COMMA_E_S_QExpression_E_C) {
	trace("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star", 2, p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, p__O_QGT_COMMA_E_S_QExpression_E_C);
	delete p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star;
    }
};
class _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C"; }
};
class _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C_rule0 : public _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C {
private:
    NIL* m_NIL;
public:
    _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C_rule0 (NIL* p_NIL) {
	m_NIL = p_NIL;
	trace("_O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C", 1, p_NIL);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NIL);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NIL);}
};
class _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C_rule1 : public _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C {
private:
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star* m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star;
    GT_RPAREN* m_GT_RPAREN;
public:
    _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C_rule1 (GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, GT_RPAREN* p_GT_RPAREN) {
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star = p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("_O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C", 4, p_GT_LPAREN, p_Expression, p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_GT_LPAREN, m_Expression, m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_GT_LPAREN, m_Expression, m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star, m_GT_RPAREN);}
};
class ConstructTemplate : public _Production {
private:
    GT_LCURLEY* m_GT_LCURLEY;
    _QConstructTriples_E_Opt* m__QConstructTriples_E_Opt;
    GT_RCURLEY* m_GT_RCURLEY;
    virtual const char* getProductionName () { return "ConstructTemplate"; }
public:
    ConstructTemplate (GT_LCURLEY* p_GT_LCURLEY, _QConstructTriples_E_Opt* p__QConstructTriples_E_Opt, GT_RCURLEY* p_GT_RCURLEY) {
	m_GT_LCURLEY = p_GT_LCURLEY;
	m__QConstructTriples_E_Opt = p__QConstructTriples_E_Opt;
	m_GT_RCURLEY = p_GT_RCURLEY;
	trace("ConstructTemplate", 3, p_GT_LCURLEY, p__QConstructTriples_E_Opt, p_GT_RCURLEY);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_GT_LCURLEY, m__QConstructTriples_E_Opt, m_GT_RCURLEY);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_GT_LCURLEY, m__QConstructTriples_E_Opt, m_GT_RCURLEY);}
};
class _QConstructTriples_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QConstructTriples_E_Opt"; }
};
class _QConstructTriples_E_Opt_rule0 : public _QConstructTriples_E_Opt {
public:
    _QConstructTriples_E_Opt_rule0 () {
	trace("_QConstructTriples_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QConstructTriples_E_Opt_rule1 : public _QConstructTriples_E_Opt {
private:
    ConstructTriples* m_ConstructTriples;
public:
    _QConstructTriples_E_Opt_rule1 (ConstructTriples* p_ConstructTriples) {
	m_ConstructTriples = p_ConstructTriples;
	trace("_QConstructTriples_E_Opt", 1, p_ConstructTriples);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_ConstructTriples);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_ConstructTriples);}
};
class ConstructTriples : public _Production {
private:
    TriplesSameSubject* m_TriplesSameSubject;
    _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt* m__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt;
    virtual const char* getProductionName () { return "ConstructTriples"; }
public:
    ConstructTriples (TriplesSameSubject* p_TriplesSameSubject, _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt* p__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt) {
	m_TriplesSameSubject = p_TriplesSameSubject;
	m__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt = p__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt;
	trace("ConstructTriples", 2, p_TriplesSameSubject, p__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_TriplesSameSubject, m__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_TriplesSameSubject, m__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt);}
};
class _O_QGT_DOT_E_S_QConstructTriples_E_Opt_C : public _Production {
private:
    GT_DOT* m_GT_DOT;
    _QConstructTriples_E_Opt* m__QConstructTriples_E_Opt;
    virtual const char* getProductionName () { return "_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C"; }
public:
    _O_QGT_DOT_E_S_QConstructTriples_E_Opt_C (GT_DOT* p_GT_DOT, _QConstructTriples_E_Opt* p__QConstructTriples_E_Opt) {
	m_GT_DOT = p_GT_DOT;
	m__QConstructTriples_E_Opt = p__QConstructTriples_E_Opt;
	trace("_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C", 2, p_GT_DOT, p__QConstructTriples_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_DOT, m__QConstructTriples_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_DOT, m__QConstructTriples_E_Opt);}
};
class _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt"; }
};
class _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt_rule0 : public _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt {
public:
    _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt_rule0 () {
	trace("_Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt_rule1 : public _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt {
private:
    _O_QGT_DOT_E_S_QConstructTriples_E_Opt_C* m__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C;
public:
    _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt_rule1 (_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C* p__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C) {
	m__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C = p__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C;
	trace("_Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt", 1, p__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C);}
};
class TriplesSameSubject : public _Production {
private:
    virtual const char * getProductionName () { return "TriplesSameSubject"; }
};
class TriplesSameSubject_rule0 : public TriplesSameSubject {
private:
    VarOrTerm* m_VarOrTerm;
    PropertyListNotEmpty* m_PropertyListNotEmpty;
public:
    TriplesSameSubject_rule0 (VarOrTerm* p_VarOrTerm, PropertyListNotEmpty* p_PropertyListNotEmpty) {
	m_VarOrTerm = p_VarOrTerm;
	m_PropertyListNotEmpty = p_PropertyListNotEmpty;
	trace("TriplesSameSubject", 2, p_VarOrTerm, p_PropertyListNotEmpty);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_VarOrTerm, m_PropertyListNotEmpty);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_VarOrTerm, m_PropertyListNotEmpty);}
};
class TriplesSameSubject_rule1 : public TriplesSameSubject {
private:
    TriplesNode* m_TriplesNode;
    PropertyList* m_PropertyList;
public:
    TriplesSameSubject_rule1 (TriplesNode* p_TriplesNode, PropertyList* p_PropertyList) {
	m_TriplesNode = p_TriplesNode;
	m_PropertyList = p_PropertyList;
	trace("TriplesSameSubject", 2, p_TriplesNode, p_PropertyList);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_TriplesNode, m_PropertyList);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_TriplesNode, m_PropertyList);}
};
class PropertyListNotEmpty : public _Production {
private:
    Verb* m_Verb;
    ObjectList* m_ObjectList;
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star* m__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star;
    virtual const char* getProductionName () { return "PropertyListNotEmpty"; }
public:
    PropertyListNotEmpty (Verb* p_Verb, ObjectList* p_ObjectList, _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star* p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star) {
	m_Verb = p_Verb;
	m_ObjectList = p_ObjectList;
	m__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star = p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star;
	trace("PropertyListNotEmpty", 3, p_Verb, p_ObjectList, p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_Verb, m_ObjectList, m__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_Verb, m_ObjectList, m__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star);}
};
class _O_QVerb_E_S_QObjectList_E_C : public _Production {
private:
    Verb* m_Verb;
    ObjectList* m_ObjectList;
    virtual const char* getProductionName () { return "_O_QVerb_E_S_QObjectList_E_C"; }
public:
    _O_QVerb_E_S_QObjectList_E_C (Verb* p_Verb, ObjectList* p_ObjectList) {
	m_Verb = p_Verb;
	m_ObjectList = p_ObjectList;
	trace("_O_QVerb_E_S_QObjectList_E_C", 2, p_Verb, p_ObjectList);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_Verb, m_ObjectList);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_Verb, m_ObjectList);}
};
class _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QVerb_E_S_QObjectList_E_C_E_Opt"; }
};
class _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt_rule0 : public _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt {
public:
    _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt_rule0 () {
	trace("_Q_O_QVerb_E_S_QObjectList_E_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt_rule1 : public _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt {
private:
    _O_QVerb_E_S_QObjectList_E_C* m__O_QVerb_E_S_QObjectList_E_C;
public:
    _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt_rule1 (_O_QVerb_E_S_QObjectList_E_C* p__O_QVerb_E_S_QObjectList_E_C) {
	m__O_QVerb_E_S_QObjectList_E_C = p__O_QVerb_E_S_QObjectList_E_C;
	trace("_Q_O_QVerb_E_S_QObjectList_E_C_E_Opt", 1, p__O_QVerb_E_S_QObjectList_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QVerb_E_S_QObjectList_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QVerb_E_S_QObjectList_E_C);}
};
class _O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C : public _Production {
private:
    GT_SEMI* m_GT_SEMI;
    _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt* m__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt;
    virtual const char* getProductionName () { return "_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C"; }
public:
    _O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C (GT_SEMI* p_GT_SEMI, _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt* p__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt) {
	m_GT_SEMI = p_GT_SEMI;
	m__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt = p__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt;
	trace("_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C", 2, p_GT_SEMI, p__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_SEMI, m__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_SEMI, m__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt);}
};
class _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star () : 
    _GenProduction("_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star", 0) {}
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star (_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C* p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C) : 
    _GenProduction("_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star", 1, p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C) {}
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star (_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star* p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star, _O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C* p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C) : 
    _GenProduction("_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star", 2, p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star, p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star"; }
};
class _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star_rule0 : public _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star {
public:
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star_rule0 () : 
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star() {
	trace("_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star", 0);
    }
};
class _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star_rule1 : public _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star {
public:
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star_rule1 (_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star* p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star, _O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C* p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C) : 
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star(p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star, p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C) {
	trace("_Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star", 2, p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star, p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C);
	delete p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star;
    }
};
class PropertyList : public _Production {
private:
    _QPropertyListNotEmpty_E_Opt* m__QPropertyListNotEmpty_E_Opt;
    virtual const char* getProductionName () { return "PropertyList"; }
public:
    PropertyList (_QPropertyListNotEmpty_E_Opt* p__QPropertyListNotEmpty_E_Opt) {
	m__QPropertyListNotEmpty_E_Opt = p__QPropertyListNotEmpty_E_Opt;
	trace("PropertyList", 1, p__QPropertyListNotEmpty_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__QPropertyListNotEmpty_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__QPropertyListNotEmpty_E_Opt);}
};
class _QPropertyListNotEmpty_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QPropertyListNotEmpty_E_Opt"; }
};
class _QPropertyListNotEmpty_E_Opt_rule0 : public _QPropertyListNotEmpty_E_Opt {
public:
    _QPropertyListNotEmpty_E_Opt_rule0 () {
	trace("_QPropertyListNotEmpty_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QPropertyListNotEmpty_E_Opt_rule1 : public _QPropertyListNotEmpty_E_Opt {
private:
    PropertyListNotEmpty* m_PropertyListNotEmpty;
public:
    _QPropertyListNotEmpty_E_Opt_rule1 (PropertyListNotEmpty* p_PropertyListNotEmpty) {
	m_PropertyListNotEmpty = p_PropertyListNotEmpty;
	trace("_QPropertyListNotEmpty_E_Opt", 1, p_PropertyListNotEmpty);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_PropertyListNotEmpty);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_PropertyListNotEmpty);}
};
class ObjectList : public _Production {
private:
    Object* m_Object;
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star* m__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star;
    virtual const char* getProductionName () { return "ObjectList"; }
public:
    ObjectList (Object* p_Object, _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star) {
	m_Object = p_Object;
	m__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star = p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star;
	trace("ObjectList", 2, p_Object, p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_Object, m__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_Object, m__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star);}
};
class _O_QGT_COMMA_E_S_QObject_E_C : public _Production {
private:
    GT_COMMA* m_GT_COMMA;
    Object* m_Object;
    virtual const char* getProductionName () { return "_O_QGT_COMMA_E_S_QObject_E_C"; }
public:
    _O_QGT_COMMA_E_S_QObject_E_C (GT_COMMA* p_GT_COMMA, Object* p_Object) {
	m_GT_COMMA = p_GT_COMMA;
	m_Object = p_Object;
	trace("_O_QGT_COMMA_E_S_QObject_E_C", 2, p_GT_COMMA, p_Object);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_COMMA, m_Object);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_COMMA, m_Object);}
};
class _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star () : 
    _GenProduction("_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star", 0) {}
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star (_O_QGT_COMMA_E_S_QObject_E_C* p__O_QGT_COMMA_E_S_QObject_E_C) : 
    _GenProduction("_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star", 1, p__O_QGT_COMMA_E_S_QObject_E_C) {}
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star (_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star, _O_QGT_COMMA_E_S_QObject_E_C* p__O_QGT_COMMA_E_S_QObject_E_C) : 
    _GenProduction("_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star", 2, p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star, p__O_QGT_COMMA_E_S_QObject_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star"; }
};
class _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star_rule0 : public _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star {
public:
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star_rule0 () : 
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star() {
	trace("_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star", 0);
    }
};
class _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star_rule1 : public _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star {
public:
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star_rule1 (_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star, _O_QGT_COMMA_E_S_QObject_E_C* p__O_QGT_COMMA_E_S_QObject_E_C) : 
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star(p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star, p__O_QGT_COMMA_E_S_QObject_E_C) {
	trace("_Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star", 2, p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star, p__O_QGT_COMMA_E_S_QObject_E_C);
	delete p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star;
    }
};
class Object : public _Production {
private:
    GraphNode* m_GraphNode;
    virtual const char* getProductionName () { return "Object"; }
public:
    Object (GraphNode* p_GraphNode) {
	m_GraphNode = p_GraphNode;
	trace("Object", 1, p_GraphNode);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GraphNode);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GraphNode);}
};
class Verb : public _Production {
private:
    virtual const char * getProductionName () { return "Verb"; }
};
class Verb_rule0 : public Verb {
private:
    VarOrIRIref* m_VarOrIRIref;
public:
    Verb_rule0 (VarOrIRIref* p_VarOrIRIref) {
	m_VarOrIRIref = p_VarOrIRIref;
	trace("Verb", 1, p_VarOrIRIref);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_VarOrIRIref);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_VarOrIRIref);}
};
class Verb_rule1 : public Verb {
private:
    IT_a* m_IT_a;
public:
    Verb_rule1 (IT_a* p_IT_a) {
	m_IT_a = p_IT_a;
	trace("Verb", 1, p_IT_a);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_a);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_a);}
};
class TriplesNode : public _Production {
private:
    virtual const char * getProductionName () { return "TriplesNode"; }
};
class TriplesNode_rule0 : public TriplesNode {
private:
    Collection* m_Collection;
public:
    TriplesNode_rule0 (Collection* p_Collection) {
	m_Collection = p_Collection;
	trace("TriplesNode", 1, p_Collection);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Collection);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Collection);}
};
class TriplesNode_rule1 : public TriplesNode {
private:
    BlankNodePropertyList* m_BlankNodePropertyList;
public:
    TriplesNode_rule1 (BlankNodePropertyList* p_BlankNodePropertyList) {
	m_BlankNodePropertyList = p_BlankNodePropertyList;
	trace("TriplesNode", 1, p_BlankNodePropertyList);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BlankNodePropertyList);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BlankNodePropertyList);}
};
class BlankNodePropertyList : public _Production {
private:
    GT_LBRACKET* m_GT_LBRACKET;
    PropertyListNotEmpty* m_PropertyListNotEmpty;
    GT_RBRACKET* m_GT_RBRACKET;
    virtual const char* getProductionName () { return "BlankNodePropertyList"; }
public:
    BlankNodePropertyList (GT_LBRACKET* p_GT_LBRACKET, PropertyListNotEmpty* p_PropertyListNotEmpty, GT_RBRACKET* p_GT_RBRACKET) {
	m_GT_LBRACKET = p_GT_LBRACKET;
	m_PropertyListNotEmpty = p_PropertyListNotEmpty;
	m_GT_RBRACKET = p_GT_RBRACKET;
	trace("BlankNodePropertyList", 3, p_GT_LBRACKET, p_PropertyListNotEmpty, p_GT_RBRACKET);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_GT_LBRACKET, m_PropertyListNotEmpty, m_GT_RBRACKET);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_GT_LBRACKET, m_PropertyListNotEmpty, m_GT_RBRACKET);}
};
class Collection : public _Production {
private:
    GT_LPAREN* m_GT_LPAREN;
    _QGraphNode_E_Plus* m__QGraphNode_E_Plus;
    GT_RPAREN* m_GT_RPAREN;
    virtual const char* getProductionName () { return "Collection"; }
public:
    Collection (GT_LPAREN* p_GT_LPAREN, _QGraphNode_E_Plus* p__QGraphNode_E_Plus, GT_RPAREN* p_GT_RPAREN) {
	m_GT_LPAREN = p_GT_LPAREN;
	m__QGraphNode_E_Plus = p__QGraphNode_E_Plus;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("Collection", 3, p_GT_LPAREN, p__QGraphNode_E_Plus, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_GT_LPAREN, m__QGraphNode_E_Plus, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_GT_LPAREN, m__QGraphNode_E_Plus, m_GT_RPAREN);}
};
class _QGraphNode_E_Plus : public _GenProduction {
protected:
    _QGraphNode_E_Plus () : 
    _GenProduction("_QGraphNode_E_Plus", 0) {}
    _QGraphNode_E_Plus (GraphNode* p_GraphNode) : 
    _GenProduction("_QGraphNode_E_Plus", 1, p_GraphNode) {}
    _QGraphNode_E_Plus (_QGraphNode_E_Plus* p__QGraphNode_E_Plus, GraphNode* p_GraphNode) : 
    _GenProduction("_QGraphNode_E_Plus", 2, p__QGraphNode_E_Plus, p_GraphNode) {}
    virtual const char * getProductionName () { return "_QGraphNode_E_Plus"; }
};
class _QGraphNode_E_Plus_rule0 : public _QGraphNode_E_Plus {
public:
    _QGraphNode_E_Plus_rule0 (GraphNode* p_GraphNode) : 
    _QGraphNode_E_Plus(p_GraphNode) {
	trace("_QGraphNode_E_Plus", 1, p_GraphNode);
    }
};
class _QGraphNode_E_Plus_rule1 : public _QGraphNode_E_Plus {
public:
    _QGraphNode_E_Plus_rule1 (_QGraphNode_E_Plus* p__QGraphNode_E_Plus, GraphNode* p_GraphNode) : 
    _QGraphNode_E_Plus(p__QGraphNode_E_Plus, p_GraphNode) {
	trace("_QGraphNode_E_Plus", 2, p__QGraphNode_E_Plus, p_GraphNode);
	delete p__QGraphNode_E_Plus;
    }
};
class GraphNode : public _Production {
private:
    virtual const char * getProductionName () { return "GraphNode"; }
};
class GraphNode_rule0 : public GraphNode {
private:
    VarOrTerm* m_VarOrTerm;
public:
    GraphNode_rule0 (VarOrTerm* p_VarOrTerm) {
	m_VarOrTerm = p_VarOrTerm;
	trace("GraphNode", 1, p_VarOrTerm);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_VarOrTerm);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_VarOrTerm);}
};
class GraphNode_rule1 : public GraphNode {
private:
    TriplesNode* m_TriplesNode;
public:
    GraphNode_rule1 (TriplesNode* p_TriplesNode) {
	m_TriplesNode = p_TriplesNode;
	trace("GraphNode", 1, p_TriplesNode);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_TriplesNode);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_TriplesNode);}
};
class VarOrTerm : public _Production {
private:
    virtual const char * getProductionName () { return "VarOrTerm"; }
};
class VarOrTerm_rule0 : public VarOrTerm {
private:
    Var* m_Var;
public:
    VarOrTerm_rule0 (Var* p_Var) {
	m_Var = p_Var;
	trace("VarOrTerm", 1, p_Var);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Var);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Var);}
};
class VarOrTerm_rule1 : public VarOrTerm {
private:
    GraphTerm* m_GraphTerm;
public:
    VarOrTerm_rule1 (GraphTerm* p_GraphTerm) {
	m_GraphTerm = p_GraphTerm;
	trace("VarOrTerm", 1, p_GraphTerm);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_GraphTerm);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_GraphTerm);}
};
class VarOrIRIref : public _Production {
private:
    virtual const char * getProductionName () { return "VarOrIRIref"; }
};
class VarOrIRIref_rule0 : public VarOrIRIref {
private:
    Var* m_Var;
public:
    VarOrIRIref_rule0 (Var* p_Var) {
	m_Var = p_Var;
	trace("VarOrIRIref", 1, p_Var);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Var);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Var);}
};
class VarOrIRIref_rule1 : public VarOrIRIref {
private:
    IRIref* m_IRIref;
public:
    VarOrIRIref_rule1 (IRIref* p_IRIref) {
	m_IRIref = p_IRIref;
	trace("VarOrIRIref", 1, p_IRIref);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IRIref);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IRIref);}
};
class Var : public _Production {
private:
    virtual const char * getProductionName () { return "Var"; }
};
class Var_rule0 : public Var {
private:
    VAR1* m_VAR1;
public:
    Var_rule0 (VAR1* p_VAR1) {
	m_VAR1 = p_VAR1;
	trace("Var", 1, p_VAR1);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_VAR1);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_VAR1);}
};
class Var_rule1 : public Var {
private:
    VAR2* m_VAR2;
public:
    Var_rule1 (VAR2* p_VAR2) {
	m_VAR2 = p_VAR2;
	trace("Var", 1, p_VAR2);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_VAR2);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_VAR2);}
};
class GraphTerm : public _Production {
private:
    virtual const char * getProductionName () { return "GraphTerm"; }
};
class GraphTerm_rule0 : public GraphTerm {
private:
    IRIref* m_IRIref;
public:
    GraphTerm_rule0 (IRIref* p_IRIref) {
	m_IRIref = p_IRIref;
	trace("GraphTerm", 1, p_IRIref);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IRIref);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IRIref);}
};
class GraphTerm_rule1 : public GraphTerm {
private:
    RDFLiteral* m_RDFLiteral;
public:
    GraphTerm_rule1 (RDFLiteral* p_RDFLiteral) {
	m_RDFLiteral = p_RDFLiteral;
	trace("GraphTerm", 1, p_RDFLiteral);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_RDFLiteral);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_RDFLiteral);}
};
class GraphTerm_rule2 : public GraphTerm {
private:
    NumericLiteral* m_NumericLiteral;
public:
    GraphTerm_rule2 (NumericLiteral* p_NumericLiteral) {
	m_NumericLiteral = p_NumericLiteral;
	trace("GraphTerm", 1, p_NumericLiteral);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteral);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteral);}
};
class GraphTerm_rule3 : public GraphTerm {
private:
    BooleanLiteral* m_BooleanLiteral;
public:
    GraphTerm_rule3 (BooleanLiteral* p_BooleanLiteral) {
	m_BooleanLiteral = p_BooleanLiteral;
	trace("GraphTerm", 1, p_BooleanLiteral);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BooleanLiteral);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BooleanLiteral);}
};
class GraphTerm_rule4 : public GraphTerm {
private:
    BlankNode* m_BlankNode;
public:
    GraphTerm_rule4 (BlankNode* p_BlankNode) {
	m_BlankNode = p_BlankNode;
	trace("GraphTerm", 1, p_BlankNode);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BlankNode);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BlankNode);}
};
class GraphTerm_rule5 : public GraphTerm {
private:
    NIL* m_NIL;
public:
    GraphTerm_rule5 (NIL* p_NIL) {
	m_NIL = p_NIL;
	trace("GraphTerm", 1, p_NIL);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NIL);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NIL);}
};
class Expression : public _Production {
private:
    ConditionalOrExpression* m_ConditionalOrExpression;
    virtual const char* getProductionName () { return "Expression"; }
public:
    Expression (ConditionalOrExpression* p_ConditionalOrExpression) {
	m_ConditionalOrExpression = p_ConditionalOrExpression;
	trace("Expression", 1, p_ConditionalOrExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_ConditionalOrExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_ConditionalOrExpression);}
};
class ConditionalOrExpression : public _Production {
private:
    ConditionalAndExpression* m_ConditionalAndExpression;
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star* m__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star;
    virtual const char* getProductionName () { return "ConditionalOrExpression"; }
public:
    ConditionalOrExpression (ConditionalAndExpression* p_ConditionalAndExpression, _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star* p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star) {
	m_ConditionalAndExpression = p_ConditionalAndExpression;
	m__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star = p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star;
	trace("ConditionalOrExpression", 2, p_ConditionalAndExpression, p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_ConditionalAndExpression, m__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_ConditionalAndExpression, m__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star);}
};
class _O_QGT_OR_E_S_QConditionalAndExpression_E_C : public _Production {
private:
    GT_OR* m_GT_OR;
    ConditionalAndExpression* m_ConditionalAndExpression;
    virtual const char* getProductionName () { return "_O_QGT_OR_E_S_QConditionalAndExpression_E_C"; }
public:
    _O_QGT_OR_E_S_QConditionalAndExpression_E_C (GT_OR* p_GT_OR, ConditionalAndExpression* p_ConditionalAndExpression) {
	m_GT_OR = p_GT_OR;
	m_ConditionalAndExpression = p_ConditionalAndExpression;
	trace("_O_QGT_OR_E_S_QConditionalAndExpression_E_C", 2, p_GT_OR, p_ConditionalAndExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_OR, m_ConditionalAndExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_OR, m_ConditionalAndExpression);}
};
class _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star () : 
    _GenProduction("_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star", 0) {}
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star (_O_QGT_OR_E_S_QConditionalAndExpression_E_C* p__O_QGT_OR_E_S_QConditionalAndExpression_E_C) : 
    _GenProduction("_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star", 1, p__O_QGT_OR_E_S_QConditionalAndExpression_E_C) {}
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star (_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star* p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star, _O_QGT_OR_E_S_QConditionalAndExpression_E_C* p__O_QGT_OR_E_S_QConditionalAndExpression_E_C) : 
    _GenProduction("_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star", 2, p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star, p__O_QGT_OR_E_S_QConditionalAndExpression_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star"; }
};
class _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star_rule0 : public _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star {
public:
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star_rule0 () : 
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star() {
	trace("_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star", 0);
    }
};
class _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star_rule1 : public _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star {
public:
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star_rule1 (_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star* p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star, _O_QGT_OR_E_S_QConditionalAndExpression_E_C* p__O_QGT_OR_E_S_QConditionalAndExpression_E_C) : 
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star(p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star, p__O_QGT_OR_E_S_QConditionalAndExpression_E_C) {
	trace("_Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star", 2, p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star, p__O_QGT_OR_E_S_QConditionalAndExpression_E_C);
	delete p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star;
    }
};
class ConditionalAndExpression : public _Production {
private:
    ValueLogical* m_ValueLogical;
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star* m__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star;
    virtual const char* getProductionName () { return "ConditionalAndExpression"; }
public:
    ConditionalAndExpression (ValueLogical* p_ValueLogical, _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star* p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star) {
	m_ValueLogical = p_ValueLogical;
	m__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star = p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star;
	trace("ConditionalAndExpression", 2, p_ValueLogical, p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_ValueLogical, m__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_ValueLogical, m__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star);}
};
class _O_QGT_AND_E_S_QValueLogical_E_C : public _Production {
private:
    GT_AND* m_GT_AND;
    ValueLogical* m_ValueLogical;
    virtual const char* getProductionName () { return "_O_QGT_AND_E_S_QValueLogical_E_C"; }
public:
    _O_QGT_AND_E_S_QValueLogical_E_C (GT_AND* p_GT_AND, ValueLogical* p_ValueLogical) {
	m_GT_AND = p_GT_AND;
	m_ValueLogical = p_ValueLogical;
	trace("_O_QGT_AND_E_S_QValueLogical_E_C", 2, p_GT_AND, p_ValueLogical);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_AND, m_ValueLogical);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_AND, m_ValueLogical);}
};
class _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star () : 
    _GenProduction("_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star", 0) {}
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star (_O_QGT_AND_E_S_QValueLogical_E_C* p__O_QGT_AND_E_S_QValueLogical_E_C) : 
    _GenProduction("_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star", 1, p__O_QGT_AND_E_S_QValueLogical_E_C) {}
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star (_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star* p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star, _O_QGT_AND_E_S_QValueLogical_E_C* p__O_QGT_AND_E_S_QValueLogical_E_C) : 
    _GenProduction("_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star", 2, p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star, p__O_QGT_AND_E_S_QValueLogical_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star"; }
};
class _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star_rule0 : public _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star {
public:
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star_rule0 () : 
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star() {
	trace("_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star", 0);
    }
};
class _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star_rule1 : public _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star {
public:
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star_rule1 (_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star* p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star, _O_QGT_AND_E_S_QValueLogical_E_C* p__O_QGT_AND_E_S_QValueLogical_E_C) : 
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star(p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star, p__O_QGT_AND_E_S_QValueLogical_E_C) {
	trace("_Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star", 2, p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star, p__O_QGT_AND_E_S_QValueLogical_E_C);
	delete p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star;
    }
};
class ValueLogical : public _Production {
private:
    RelationalExpression* m_RelationalExpression;
    virtual const char* getProductionName () { return "ValueLogical"; }
public:
    ValueLogical (RelationalExpression* p_RelationalExpression) {
	m_RelationalExpression = p_RelationalExpression;
	trace("ValueLogical", 1, p_RelationalExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_RelationalExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_RelationalExpression);}
};
class RelationalExpression : public _Production {
private:
    NumericExpression* m_NumericExpression;
    _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt* m__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt;
    virtual const char* getProductionName () { return "RelationalExpression"; }
public:
    RelationalExpression (NumericExpression* p_NumericExpression, _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt* p__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt) {
	m_NumericExpression = p_NumericExpression;
	m__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt = p__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt;
	trace("RelationalExpression", 2, p_NumericExpression, p__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_NumericExpression, m__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_NumericExpression, m__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt);}
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C"; }
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule0 : public _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C {
private:
    GT_EQUAL* m_GT_EQUAL;
    NumericExpression* m_NumericExpression;
public:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule0 (GT_EQUAL* p_GT_EQUAL, NumericExpression* p_NumericExpression) {
	m_GT_EQUAL = p_GT_EQUAL;
	m_NumericExpression = p_NumericExpression;
	trace("_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C", 2, p_GT_EQUAL, p_NumericExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_EQUAL, m_NumericExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_EQUAL, m_NumericExpression);}
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule1 : public _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C {
private:
    GT_NEQUAL* m_GT_NEQUAL;
    NumericExpression* m_NumericExpression;
public:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule1 (GT_NEQUAL* p_GT_NEQUAL, NumericExpression* p_NumericExpression) {
	m_GT_NEQUAL = p_GT_NEQUAL;
	m_NumericExpression = p_NumericExpression;
	trace("_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C", 2, p_GT_NEQUAL, p_NumericExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_NEQUAL, m_NumericExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_NEQUAL, m_NumericExpression);}
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule2 : public _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C {
private:
    GT_LT* m_GT_LT;
    NumericExpression* m_NumericExpression;
public:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule2 (GT_LT* p_GT_LT, NumericExpression* p_NumericExpression) {
	m_GT_LT = p_GT_LT;
	m_NumericExpression = p_NumericExpression;
	trace("_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C", 2, p_GT_LT, p_NumericExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_LT, m_NumericExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_LT, m_NumericExpression);}
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule3 : public _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C {
private:
    GT_GT* m_GT_GT;
    NumericExpression* m_NumericExpression;
public:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule3 (GT_GT* p_GT_GT, NumericExpression* p_NumericExpression) {
	m_GT_GT = p_GT_GT;
	m_NumericExpression = p_NumericExpression;
	trace("_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C", 2, p_GT_GT, p_NumericExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_GT, m_NumericExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_GT, m_NumericExpression);}
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule4 : public _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C {
private:
    GT_LE* m_GT_LE;
    NumericExpression* m_NumericExpression;
public:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule4 (GT_LE* p_GT_LE, NumericExpression* p_NumericExpression) {
	m_GT_LE = p_GT_LE;
	m_NumericExpression = p_NumericExpression;
	trace("_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C", 2, p_GT_LE, p_NumericExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_LE, m_NumericExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_LE, m_NumericExpression);}
};
class _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule5 : public _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C {
private:
    GT_GE* m_GT_GE;
    NumericExpression* m_NumericExpression;
public:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_rule5 (GT_GE* p_GT_GE, NumericExpression* p_NumericExpression) {
	m_GT_GE = p_GT_GE;
	m_NumericExpression = p_NumericExpression;
	trace("_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C", 2, p_GT_GE, p_NumericExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_GE, m_NumericExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_GE, m_NumericExpression);}
};
class _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt"; }
};
class _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt_rule0 : public _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt {
public:
    _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt_rule0 () {
	trace("_Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt_rule1 : public _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt {
private:
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C* m__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C;
public:
    _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt_rule1 (_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C* p__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C) {
	m__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C = p__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C;
	trace("_Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt", 1, p__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C);}
};
class NumericExpression : public _Production {
private:
    AdditiveExpression* m_AdditiveExpression;
    virtual const char* getProductionName () { return "NumericExpression"; }
public:
    NumericExpression (AdditiveExpression* p_AdditiveExpression) {
	m_AdditiveExpression = p_AdditiveExpression;
	trace("NumericExpression", 1, p_AdditiveExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_AdditiveExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_AdditiveExpression);}
};
class AdditiveExpression : public _Production {
private:
    MultiplicativeExpression* m_MultiplicativeExpression;
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star* m__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star;
    virtual const char* getProductionName () { return "AdditiveExpression"; }
public:
    AdditiveExpression (MultiplicativeExpression* p_MultiplicativeExpression, _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star* p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star) {
	m_MultiplicativeExpression = p_MultiplicativeExpression;
	m__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star = p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star;
	trace("AdditiveExpression", 2, p_MultiplicativeExpression, p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_MultiplicativeExpression, m__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_MultiplicativeExpression, m__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star);}
};
class _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C"; }
};
class _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule0 : public _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C {
private:
    GT_PLUS* m_GT_PLUS;
    MultiplicativeExpression* m_MultiplicativeExpression;
public:
    _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule0 (GT_PLUS* p_GT_PLUS, MultiplicativeExpression* p_MultiplicativeExpression) {
	m_GT_PLUS = p_GT_PLUS;
	m_MultiplicativeExpression = p_MultiplicativeExpression;
	trace("_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C", 2, p_GT_PLUS, p_MultiplicativeExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_PLUS, m_MultiplicativeExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_PLUS, m_MultiplicativeExpression);}
};
class _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule1 : public _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C {
private:
    GT_MINUS* m_GT_MINUS;
    MultiplicativeExpression* m_MultiplicativeExpression;
public:
    _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule1 (GT_MINUS* p_GT_MINUS, MultiplicativeExpression* p_MultiplicativeExpression) {
	m_GT_MINUS = p_GT_MINUS;
	m_MultiplicativeExpression = p_MultiplicativeExpression;
	trace("_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C", 2, p_GT_MINUS, p_MultiplicativeExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_MINUS, m_MultiplicativeExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_MINUS, m_MultiplicativeExpression);}
};
class _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule2 : public _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C {
private:
    NumericLiteralPositive* m_NumericLiteralPositive;
public:
    _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule2 (NumericLiteralPositive* p_NumericLiteralPositive) {
	m_NumericLiteralPositive = p_NumericLiteralPositive;
	trace("_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C", 1, p_NumericLiteralPositive);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteralPositive);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteralPositive);}
};
class _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule3 : public _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C {
private:
    NumericLiteralNegative* m_NumericLiteralNegative;
public:
    _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_rule3 (NumericLiteralNegative* p_NumericLiteralNegative) {
	m_NumericLiteralNegative = p_NumericLiteralNegative;
	trace("_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C", 1, p_NumericLiteralNegative);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteralNegative);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteralNegative);}
};
class _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star () : 
    _GenProduction("_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star", 0) {}
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star (_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C* p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C) : 
    _GenProduction("_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star", 1, p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C) {}
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star (_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star* p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star, _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C* p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C) : 
    _GenProduction("_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star", 2, p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star, p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star"; }
};
class _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star_rule0 : public _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star {
public:
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star_rule0 () : 
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star() {
	trace("_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star", 0);
    }
};
class _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star_rule1 : public _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star {
public:
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star_rule1 (_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star* p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star, _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C* p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C) : 
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star(p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star, p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C) {
	trace("_Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star", 2, p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star, p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C);
	delete p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star;
    }
};
class MultiplicativeExpression : public _Production {
private:
    UnaryExpression* m_UnaryExpression;
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star* m__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star;
    virtual const char* getProductionName () { return "MultiplicativeExpression"; }
public:
    MultiplicativeExpression (UnaryExpression* p_UnaryExpression, _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star* p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star) {
	m_UnaryExpression = p_UnaryExpression;
	m__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star = p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star;
	trace("MultiplicativeExpression", 2, p_UnaryExpression, p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_UnaryExpression, m__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_UnaryExpression, m__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star);}
};
class _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C"; }
};
class _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_rule0 : public _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C {
private:
    GT_TIMES* m_GT_TIMES;
    UnaryExpression* m_UnaryExpression;
public:
    _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_rule0 (GT_TIMES* p_GT_TIMES, UnaryExpression* p_UnaryExpression) {
	m_GT_TIMES = p_GT_TIMES;
	m_UnaryExpression = p_UnaryExpression;
	trace("_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C", 2, p_GT_TIMES, p_UnaryExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_TIMES, m_UnaryExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_TIMES, m_UnaryExpression);}
};
class _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_rule1 : public _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C {
private:
    GT_DIVIDE* m_GT_DIVIDE;
    UnaryExpression* m_UnaryExpression;
public:
    _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_rule1 (GT_DIVIDE* p_GT_DIVIDE, UnaryExpression* p_UnaryExpression) {
	m_GT_DIVIDE = p_GT_DIVIDE;
	m_UnaryExpression = p_UnaryExpression;
	trace("_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C", 2, p_GT_DIVIDE, p_UnaryExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_DIVIDE, m_UnaryExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_DIVIDE, m_UnaryExpression);}
};
class _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star : public _GenProduction {
protected:
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star () : 
    _GenProduction("_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star", 0) {}
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star (_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C* p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C) : 
    _GenProduction("_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star", 1, p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C) {}
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star (_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star* p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star, _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C* p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C) : 
    _GenProduction("_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star", 2, p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star, p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C) {}
    virtual const char * getProductionName () { return "_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star"; }
};
class _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star_rule0 : public _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star {
public:
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star_rule0 () : 
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star() {
	trace("_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star", 0);
    }
};
class _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star_rule1 : public _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star {
public:
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star_rule1 (_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star* p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star, _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C* p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C) : 
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star(p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star, p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C) {
	trace("_Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star", 2, p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star, p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C);
	delete p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star;
    }
};
class UnaryExpression : public _Production {
private:
    virtual const char * getProductionName () { return "UnaryExpression"; }
};
class UnaryExpression_rule0 : public UnaryExpression {
private:
    GT_NOT* m_GT_NOT;
    PrimaryExpression* m_PrimaryExpression;
public:
    UnaryExpression_rule0 (GT_NOT* p_GT_NOT, PrimaryExpression* p_PrimaryExpression) {
	m_GT_NOT = p_GT_NOT;
	m_PrimaryExpression = p_PrimaryExpression;
	trace("UnaryExpression", 2, p_GT_NOT, p_PrimaryExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_NOT, m_PrimaryExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_NOT, m_PrimaryExpression);}
};
class UnaryExpression_rule1 : public UnaryExpression {
private:
    GT_PLUS* m_GT_PLUS;
    PrimaryExpression* m_PrimaryExpression;
public:
    UnaryExpression_rule1 (GT_PLUS* p_GT_PLUS, PrimaryExpression* p_PrimaryExpression) {
	m_GT_PLUS = p_GT_PLUS;
	m_PrimaryExpression = p_PrimaryExpression;
	trace("UnaryExpression", 2, p_GT_PLUS, p_PrimaryExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_PLUS, m_PrimaryExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_PLUS, m_PrimaryExpression);}
};
class UnaryExpression_rule2 : public UnaryExpression {
private:
    GT_MINUS* m_GT_MINUS;
    PrimaryExpression* m_PrimaryExpression;
public:
    UnaryExpression_rule2 (GT_MINUS* p_GT_MINUS, PrimaryExpression* p_PrimaryExpression) {
	m_GT_MINUS = p_GT_MINUS;
	m_PrimaryExpression = p_PrimaryExpression;
	trace("UnaryExpression", 2, p_GT_MINUS, p_PrimaryExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_MINUS, m_PrimaryExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_MINUS, m_PrimaryExpression);}
};
class UnaryExpression_rule3 : public UnaryExpression {
private:
    PrimaryExpression* m_PrimaryExpression;
public:
    UnaryExpression_rule3 (PrimaryExpression* p_PrimaryExpression) {
	m_PrimaryExpression = p_PrimaryExpression;
	trace("UnaryExpression", 1, p_PrimaryExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_PrimaryExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_PrimaryExpression);}
};
class PrimaryExpression : public _Production {
private:
    virtual const char * getProductionName () { return "PrimaryExpression"; }
};
class PrimaryExpression_rule0 : public PrimaryExpression {
private:
    BrackettedExpression* m_BrackettedExpression;
public:
    PrimaryExpression_rule0 (BrackettedExpression* p_BrackettedExpression) {
	m_BrackettedExpression = p_BrackettedExpression;
	trace("PrimaryExpression", 1, p_BrackettedExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BrackettedExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BrackettedExpression);}
};
class PrimaryExpression_rule1 : public PrimaryExpression {
private:
    BuiltInCall* m_BuiltInCall;
public:
    PrimaryExpression_rule1 (BuiltInCall* p_BuiltInCall) {
	m_BuiltInCall = p_BuiltInCall;
	trace("PrimaryExpression", 1, p_BuiltInCall);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BuiltInCall);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BuiltInCall);}
};
class PrimaryExpression_rule2 : public PrimaryExpression {
private:
    IRIrefOrFunction* m_IRIrefOrFunction;
public:
    PrimaryExpression_rule2 (IRIrefOrFunction* p_IRIrefOrFunction) {
	m_IRIrefOrFunction = p_IRIrefOrFunction;
	trace("PrimaryExpression", 1, p_IRIrefOrFunction);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IRIrefOrFunction);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IRIrefOrFunction);}
};
class PrimaryExpression_rule3 : public PrimaryExpression {
private:
    RDFLiteral* m_RDFLiteral;
public:
    PrimaryExpression_rule3 (RDFLiteral* p_RDFLiteral) {
	m_RDFLiteral = p_RDFLiteral;
	trace("PrimaryExpression", 1, p_RDFLiteral);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_RDFLiteral);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_RDFLiteral);}
};
class PrimaryExpression_rule4 : public PrimaryExpression {
private:
    NumericLiteral* m_NumericLiteral;
public:
    PrimaryExpression_rule4 (NumericLiteral* p_NumericLiteral) {
	m_NumericLiteral = p_NumericLiteral;
	trace("PrimaryExpression", 1, p_NumericLiteral);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteral);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteral);}
};
class PrimaryExpression_rule5 : public PrimaryExpression {
private:
    BooleanLiteral* m_BooleanLiteral;
public:
    PrimaryExpression_rule5 (BooleanLiteral* p_BooleanLiteral) {
	m_BooleanLiteral = p_BooleanLiteral;
	trace("PrimaryExpression", 1, p_BooleanLiteral);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BooleanLiteral);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BooleanLiteral);}
};
class PrimaryExpression_rule6 : public PrimaryExpression {
private:
    Var* m_Var;
public:
    PrimaryExpression_rule6 (Var* p_Var) {
	m_Var = p_Var;
	trace("PrimaryExpression", 1, p_Var);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_Var);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_Var);}
};
class BrackettedExpression : public _Production {
private:
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
    virtual const char* getProductionName () { return "BrackettedExpression"; }
public:
    BrackettedExpression (GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BrackettedExpression", 3, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 3, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 3, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall : public _Production {
private:
    virtual const char * getProductionName () { return "BuiltInCall"; }
};
class BuiltInCall_rule0 : public BuiltInCall {
private:
    IT_STR* m_IT_STR;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule0 (IT_STR* p_IT_STR, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_STR = p_IT_STR;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_STR, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_STR, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_STR, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule1 : public BuiltInCall {
private:
    IT_LANG* m_IT_LANG;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule1 (IT_LANG* p_IT_LANG, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_LANG = p_IT_LANG;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_LANG, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_LANG, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_LANG, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule2 : public BuiltInCall {
private:
    IT_LANGMATCHES* m_IT_LANGMATCHES;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_COMMA* m_GT_COMMA;
    Expression* m_Expression_;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule2 (IT_LANGMATCHES* p_IT_LANGMATCHES, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_COMMA* p_GT_COMMA, Expression* p_Expression_, GT_RPAREN* p_GT_RPAREN) {
	m_IT_LANGMATCHES = p_IT_LANGMATCHES;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_COMMA = p_GT_COMMA;
	m_Expression_ = p_Expression_;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 6, p_IT_LANGMATCHES, p_GT_LPAREN, p_Expression, p_GT_COMMA, p_Expression_, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 6, m_IT_LANGMATCHES, m_GT_LPAREN, m_Expression, m_GT_COMMA, m_Expression_, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 6, m_IT_LANGMATCHES, m_GT_LPAREN, m_Expression, m_GT_COMMA, m_Expression_, m_GT_RPAREN);}
};
class BuiltInCall_rule3 : public BuiltInCall {
private:
    IT_DATATYPE* m_IT_DATATYPE;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule3 (IT_DATATYPE* p_IT_DATATYPE, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_DATATYPE = p_IT_DATATYPE;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_DATATYPE, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_DATATYPE, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_DATATYPE, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule4 : public BuiltInCall {
private:
    IT_BOUND* m_IT_BOUND;
    GT_LPAREN* m_GT_LPAREN;
    Var* m_Var;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule4 (IT_BOUND* p_IT_BOUND, GT_LPAREN* p_GT_LPAREN, Var* p_Var, GT_RPAREN* p_GT_RPAREN) {
	m_IT_BOUND = p_IT_BOUND;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Var = p_Var;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_BOUND, p_GT_LPAREN, p_Var, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_BOUND, m_GT_LPAREN, m_Var, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_BOUND, m_GT_LPAREN, m_Var, m_GT_RPAREN);}
};
class BuiltInCall_rule5 : public BuiltInCall {
private:
    IT_sameTerm* m_IT_sameTerm;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_COMMA* m_GT_COMMA;
    Expression* m_Expression_;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule5 (IT_sameTerm* p_IT_sameTerm, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_COMMA* p_GT_COMMA, Expression* p_Expression_, GT_RPAREN* p_GT_RPAREN) {
	m_IT_sameTerm = p_IT_sameTerm;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_COMMA = p_GT_COMMA;
	m_Expression_ = p_Expression_;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 6, p_IT_sameTerm, p_GT_LPAREN, p_Expression, p_GT_COMMA, p_Expression_, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 6, m_IT_sameTerm, m_GT_LPAREN, m_Expression, m_GT_COMMA, m_Expression_, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 6, m_IT_sameTerm, m_GT_LPAREN, m_Expression, m_GT_COMMA, m_Expression_, m_GT_RPAREN);}
};
class BuiltInCall_rule6 : public BuiltInCall {
private:
    IT_isIRI* m_IT_isIRI;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule6 (IT_isIRI* p_IT_isIRI, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_isIRI = p_IT_isIRI;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_isIRI, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_isIRI, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_isIRI, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule7 : public BuiltInCall {
private:
    IT_isURI* m_IT_isURI;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule7 (IT_isURI* p_IT_isURI, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_isURI = p_IT_isURI;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_isURI, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_isURI, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_isURI, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule8 : public BuiltInCall {
private:
    IT_isBLANK* m_IT_isBLANK;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule8 (IT_isBLANK* p_IT_isBLANK, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_isBLANK = p_IT_isBLANK;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_isBLANK, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_isBLANK, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_isBLANK, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule9 : public BuiltInCall {
private:
    IT_isLITERAL* m_IT_isLITERAL;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_RPAREN* m_GT_RPAREN;
public:
    BuiltInCall_rule9 (IT_isLITERAL* p_IT_isLITERAL, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_RPAREN* p_GT_RPAREN) {
	m_IT_isLITERAL = p_IT_isLITERAL;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("BuiltInCall", 4, p_IT_isLITERAL, p_GT_LPAREN, p_Expression, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 4, m_IT_isLITERAL, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 4, m_IT_isLITERAL, m_GT_LPAREN, m_Expression, m_GT_RPAREN);}
};
class BuiltInCall_rule10 : public BuiltInCall {
private:
    RegexExpression* m_RegexExpression;
public:
    BuiltInCall_rule10 (RegexExpression* p_RegexExpression) {
	m_RegexExpression = p_RegexExpression;
	trace("BuiltInCall", 1, p_RegexExpression);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_RegexExpression);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_RegexExpression);}
};
class RegexExpression : public _Production {
private:
    IT_REGEX* m_IT_REGEX;
    GT_LPAREN* m_GT_LPAREN;
    Expression* m_Expression;
    GT_COMMA* m_GT_COMMA;
    Expression* m_Expression_;
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt* m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt;
    GT_RPAREN* m_GT_RPAREN;
    virtual const char* getProductionName () { return "RegexExpression"; }
public:
    RegexExpression (IT_REGEX* p_IT_REGEX, GT_LPAREN* p_GT_LPAREN, Expression* p_Expression, GT_COMMA* p_GT_COMMA, Expression* p_Expression_, _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt* p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt, GT_RPAREN* p_GT_RPAREN) {
	m_IT_REGEX = p_IT_REGEX;
	m_GT_LPAREN = p_GT_LPAREN;
	m_Expression = p_Expression;
	m_GT_COMMA = p_GT_COMMA;
	m_Expression_ = p_Expression_;
	m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt = p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt;
	m_GT_RPAREN = p_GT_RPAREN;
	trace("RegexExpression", 7, p_IT_REGEX, p_GT_LPAREN, p_Expression, p_GT_COMMA, p_Expression_, p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt, p_GT_RPAREN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 7, m_IT_REGEX, m_GT_LPAREN, m_Expression, m_GT_COMMA, m_Expression_, m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt, m_GT_RPAREN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 7, m_IT_REGEX, m_GT_LPAREN, m_Expression, m_GT_COMMA, m_Expression_, m__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt, m_GT_RPAREN);}
};
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt"; }
};
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt_rule0 : public _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt {
public:
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt_rule0 () {
	trace("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt_rule1 : public _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt {
private:
    _O_QGT_COMMA_E_S_QExpression_E_C* m__O_QGT_COMMA_E_S_QExpression_E_C;
public:
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt_rule1 (_O_QGT_COMMA_E_S_QExpression_E_C* p__O_QGT_COMMA_E_S_QExpression_E_C) {
	m__O_QGT_COMMA_E_S_QExpression_E_C = p__O_QGT_COMMA_E_S_QExpression_E_C;
	trace("_Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt", 1, p__O_QGT_COMMA_E_S_QExpression_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QGT_COMMA_E_S_QExpression_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QGT_COMMA_E_S_QExpression_E_C);}
};
class IRIrefOrFunction : public _Production {
private:
    IRIref* m_IRIref;
    _QArgList_E_Opt* m__QArgList_E_Opt;
    virtual const char* getProductionName () { return "IRIrefOrFunction"; }
public:
    IRIrefOrFunction (IRIref* p_IRIref, _QArgList_E_Opt* p__QArgList_E_Opt) {
	m_IRIref = p_IRIref;
	m__QArgList_E_Opt = p__QArgList_E_Opt;
	trace("IRIrefOrFunction", 2, p_IRIref, p__QArgList_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_IRIref, m__QArgList_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_IRIref, m__QArgList_E_Opt);}
};
class _QArgList_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_QArgList_E_Opt"; }
};
class _QArgList_E_Opt_rule0 : public _QArgList_E_Opt {
public:
    _QArgList_E_Opt_rule0 () {
	trace("_QArgList_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _QArgList_E_Opt_rule1 : public _QArgList_E_Opt {
private:
    ArgList* m_ArgList;
public:
    _QArgList_E_Opt_rule1 (ArgList* p_ArgList) {
	m_ArgList = p_ArgList;
	trace("_QArgList_E_Opt", 1, p_ArgList);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_ArgList);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_ArgList);}
};
class RDFLiteral : public _Production {
private:
    String* m_String;
    _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt* m__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt;
    virtual const char* getProductionName () { return "RDFLiteral"; }
public:
    RDFLiteral (String* p_String, _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt* p__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt) {
	m_String = p_String;
	m__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt = p__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt;
	trace("RDFLiteral", 2, p_String, p__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_String, m__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_String, m__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt);}
};
class _O_QGT_DTYPE_E_S_QIRIref_E_C : public _Production {
private:
    GT_DTYPE* m_GT_DTYPE;
    IRIref* m_IRIref;
    virtual const char* getProductionName () { return "_O_QGT_DTYPE_E_S_QIRIref_E_C"; }
public:
    _O_QGT_DTYPE_E_S_QIRIref_E_C (GT_DTYPE* p_GT_DTYPE, IRIref* p_IRIref) {
	m_GT_DTYPE = p_GT_DTYPE;
	m_IRIref = p_IRIref;
	trace("_O_QGT_DTYPE_E_S_QIRIref_E_C", 2, p_GT_DTYPE, p_IRIref);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 2, m_GT_DTYPE, m_IRIref);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 2, m_GT_DTYPE, m_IRIref);}
};
class _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C : public _Production {
private:
    virtual const char * getProductionName () { return "_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C"; }
};
class _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_rule0 : public _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C {
private:
    LANGTAG* m_LANGTAG;
public:
    _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_rule0 (LANGTAG* p_LANGTAG) {
	m_LANGTAG = p_LANGTAG;
	trace("_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C", 1, p_LANGTAG);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_LANGTAG);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_LANGTAG);}
};
class _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_rule1 : public _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C {
private:
    _O_QGT_DTYPE_E_S_QIRIref_E_C* m__O_QGT_DTYPE_E_S_QIRIref_E_C;
public:
    _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_rule1 (_O_QGT_DTYPE_E_S_QIRIref_E_C* p__O_QGT_DTYPE_E_S_QIRIref_E_C) {
	m__O_QGT_DTYPE_E_S_QIRIref_E_C = p__O_QGT_DTYPE_E_S_QIRIref_E_C;
	trace("_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C", 1, p__O_QGT_DTYPE_E_S_QIRIref_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QGT_DTYPE_E_S_QIRIref_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QGT_DTYPE_E_S_QIRIref_E_C);}
};
class _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt : public _Production {
private:
    virtual const char * getProductionName () { return "_Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt"; }
};
class _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt_rule0 : public _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt {
public:
    _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt_rule0 () {
	trace("_Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt", 0);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 0);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 0);}
};
class _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt_rule1 : public _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt {
private:
    _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C* m__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C;
public:
    _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt_rule1 (_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C* p__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C) {
	m__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C = p__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C;
	trace("_Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt", 1, p__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C);}
};
class NumericLiteral : public _Production {
private:
    virtual const char * getProductionName () { return "NumericLiteral"; }
};
class NumericLiteral_rule0 : public NumericLiteral {
private:
    NumericLiteralUnsigned* m_NumericLiteralUnsigned;
public:
    NumericLiteral_rule0 (NumericLiteralUnsigned* p_NumericLiteralUnsigned) {
	m_NumericLiteralUnsigned = p_NumericLiteralUnsigned;
	trace("NumericLiteral", 1, p_NumericLiteralUnsigned);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteralUnsigned);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteralUnsigned);}
};
class NumericLiteral_rule1 : public NumericLiteral {
private:
    NumericLiteralPositive* m_NumericLiteralPositive;
public:
    NumericLiteral_rule1 (NumericLiteralPositive* p_NumericLiteralPositive) {
	m_NumericLiteralPositive = p_NumericLiteralPositive;
	trace("NumericLiteral", 1, p_NumericLiteralPositive);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteralPositive);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteralPositive);}
};
class NumericLiteral_rule2 : public NumericLiteral {
private:
    NumericLiteralNegative* m_NumericLiteralNegative;
public:
    NumericLiteral_rule2 (NumericLiteralNegative* p_NumericLiteralNegative) {
	m_NumericLiteralNegative = p_NumericLiteralNegative;
	trace("NumericLiteral", 1, p_NumericLiteralNegative);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_NumericLiteralNegative);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_NumericLiteralNegative);}
};
class NumericLiteralUnsigned : public _Production {
private:
    virtual const char * getProductionName () { return "NumericLiteralUnsigned"; }
};
class NumericLiteralUnsigned_rule0 : public NumericLiteralUnsigned {
private:
    INTEGER* m_INTEGER;
public:
    NumericLiteralUnsigned_rule0 (INTEGER* p_INTEGER) {
	m_INTEGER = p_INTEGER;
	trace("NumericLiteralUnsigned", 1, p_INTEGER);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_INTEGER);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_INTEGER);}
};
class NumericLiteralUnsigned_rule1 : public NumericLiteralUnsigned {
private:
    DECIMAL* m_DECIMAL;
public:
    NumericLiteralUnsigned_rule1 (DECIMAL* p_DECIMAL) {
	m_DECIMAL = p_DECIMAL;
	trace("NumericLiteralUnsigned", 1, p_DECIMAL);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DECIMAL);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DECIMAL);}
};
class NumericLiteralUnsigned_rule2 : public NumericLiteralUnsigned {
private:
    DOUBLE* m_DOUBLE;
public:
    NumericLiteralUnsigned_rule2 (DOUBLE* p_DOUBLE) {
	m_DOUBLE = p_DOUBLE;
	trace("NumericLiteralUnsigned", 1, p_DOUBLE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DOUBLE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DOUBLE);}
};
class NumericLiteralPositive : public _Production {
private:
    virtual const char * getProductionName () { return "NumericLiteralPositive"; }
};
class NumericLiteralPositive_rule0 : public NumericLiteralPositive {
private:
    INTEGER_POSITIVE* m_INTEGER_POSITIVE;
public:
    NumericLiteralPositive_rule0 (INTEGER_POSITIVE* p_INTEGER_POSITIVE) {
	m_INTEGER_POSITIVE = p_INTEGER_POSITIVE;
	trace("NumericLiteralPositive", 1, p_INTEGER_POSITIVE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_INTEGER_POSITIVE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_INTEGER_POSITIVE);}
};
class NumericLiteralPositive_rule1 : public NumericLiteralPositive {
private:
    DECIMAL_POSITIVE* m_DECIMAL_POSITIVE;
public:
    NumericLiteralPositive_rule1 (DECIMAL_POSITIVE* p_DECIMAL_POSITIVE) {
	m_DECIMAL_POSITIVE = p_DECIMAL_POSITIVE;
	trace("NumericLiteralPositive", 1, p_DECIMAL_POSITIVE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DECIMAL_POSITIVE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DECIMAL_POSITIVE);}
};
class NumericLiteralPositive_rule2 : public NumericLiteralPositive {
private:
    DOUBLE_POSITIVE* m_DOUBLE_POSITIVE;
public:
    NumericLiteralPositive_rule2 (DOUBLE_POSITIVE* p_DOUBLE_POSITIVE) {
	m_DOUBLE_POSITIVE = p_DOUBLE_POSITIVE;
	trace("NumericLiteralPositive", 1, p_DOUBLE_POSITIVE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DOUBLE_POSITIVE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DOUBLE_POSITIVE);}
};
class NumericLiteralNegative : public _Production {
private:
    virtual const char * getProductionName () { return "NumericLiteralNegative"; }
};
class NumericLiteralNegative_rule0 : public NumericLiteralNegative {
private:
    INTEGER_NEGATIVE* m_INTEGER_NEGATIVE;
public:
    NumericLiteralNegative_rule0 (INTEGER_NEGATIVE* p_INTEGER_NEGATIVE) {
	m_INTEGER_NEGATIVE = p_INTEGER_NEGATIVE;
	trace("NumericLiteralNegative", 1, p_INTEGER_NEGATIVE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_INTEGER_NEGATIVE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_INTEGER_NEGATIVE);}
};
class NumericLiteralNegative_rule1 : public NumericLiteralNegative {
private:
    DECIMAL_NEGATIVE* m_DECIMAL_NEGATIVE;
public:
    NumericLiteralNegative_rule1 (DECIMAL_NEGATIVE* p_DECIMAL_NEGATIVE) {
	m_DECIMAL_NEGATIVE = p_DECIMAL_NEGATIVE;
	trace("NumericLiteralNegative", 1, p_DECIMAL_NEGATIVE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DECIMAL_NEGATIVE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DECIMAL_NEGATIVE);}
};
class NumericLiteralNegative_rule2 : public NumericLiteralNegative {
private:
    DOUBLE_NEGATIVE* m_DOUBLE_NEGATIVE;
public:
    NumericLiteralNegative_rule2 (DOUBLE_NEGATIVE* p_DOUBLE_NEGATIVE) {
	m_DOUBLE_NEGATIVE = p_DOUBLE_NEGATIVE;
	trace("NumericLiteralNegative", 1, p_DOUBLE_NEGATIVE);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_DOUBLE_NEGATIVE);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_DOUBLE_NEGATIVE);}
};
class BooleanLiteral : public _Production {
private:
    virtual const char * getProductionName () { return "BooleanLiteral"; }
};
class BooleanLiteral_rule0 : public BooleanLiteral {
private:
    IT_true* m_IT_true;
public:
    BooleanLiteral_rule0 (IT_true* p_IT_true) {
	m_IT_true = p_IT_true;
	trace("BooleanLiteral", 1, p_IT_true);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_true);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_true);}
};
class BooleanLiteral_rule1 : public BooleanLiteral {
private:
    IT_false* m_IT_false;
public:
    BooleanLiteral_rule1 (IT_false* p_IT_false) {
	m_IT_false = p_IT_false;
	trace("BooleanLiteral", 1, p_IT_false);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IT_false);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IT_false);}
};
class String : public _Production {
private:
    virtual const char * getProductionName () { return "String"; }
};
class String_rule0 : public String {
private:
    STRING_LITERAL1* m_STRING_LITERAL1;
public:
    String_rule0 (STRING_LITERAL1* p_STRING_LITERAL1) {
	m_STRING_LITERAL1 = p_STRING_LITERAL1;
	trace("String", 1, p_STRING_LITERAL1);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_STRING_LITERAL1);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_STRING_LITERAL1);}
};
class String_rule1 : public String {
private:
    STRING_LITERAL2* m_STRING_LITERAL2;
public:
    String_rule1 (STRING_LITERAL2* p_STRING_LITERAL2) {
	m_STRING_LITERAL2 = p_STRING_LITERAL2;
	trace("String", 1, p_STRING_LITERAL2);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_STRING_LITERAL2);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_STRING_LITERAL2);}
};
class String_rule2 : public String {
private:
    STRING_LITERAL_LONG1* m_STRING_LITERAL_LONG1;
public:
    String_rule2 (STRING_LITERAL_LONG1* p_STRING_LITERAL_LONG1) {
	m_STRING_LITERAL_LONG1 = p_STRING_LITERAL_LONG1;
	trace("String", 1, p_STRING_LITERAL_LONG1);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_STRING_LITERAL_LONG1);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_STRING_LITERAL_LONG1);}
};
class String_rule3 : public String {
private:
    STRING_LITERAL_LONG2* m_STRING_LITERAL_LONG2;
public:
    String_rule3 (STRING_LITERAL_LONG2* p_STRING_LITERAL_LONG2) {
	m_STRING_LITERAL_LONG2 = p_STRING_LITERAL_LONG2;
	trace("String", 1, p_STRING_LITERAL_LONG2);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_STRING_LITERAL_LONG2);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_STRING_LITERAL_LONG2);}
};
class IRIref : public _Production {
private:
    virtual const char * getProductionName () { return "IRIref"; }
};
class IRIref_rule0 : public IRIref {
private:
    IRI_REF* m_IRI_REF;
public:
    IRIref_rule0 (IRI_REF* p_IRI_REF) {
	m_IRI_REF = p_IRI_REF;
	trace("IRIref", 1, p_IRI_REF);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_IRI_REF);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_IRI_REF);}
};
class IRIref_rule1 : public IRIref {
private:
    PrefixedName* m_PrefixedName;
public:
    IRIref_rule1 (PrefixedName* p_PrefixedName) {
	m_PrefixedName = p_PrefixedName;
	trace("IRIref", 1, p_PrefixedName);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_PrefixedName);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_PrefixedName);}
};
class PrefixedName : public _Production {
private:
    virtual const char * getProductionName () { return "PrefixedName"; }
};
class PrefixedName_rule0 : public PrefixedName {
private:
    PNAME_LN* m_PNAME_LN;
public:
    PrefixedName_rule0 (PNAME_LN* p_PNAME_LN) {
	m_PNAME_LN = p_PNAME_LN;
	trace("PrefixedName", 1, p_PNAME_LN);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_PNAME_LN);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_PNAME_LN);}
};
class PrefixedName_rule1 : public PrefixedName {
private:
    PNAME_NS* m_PNAME_NS;
public:
    PrefixedName_rule1 (PNAME_NS* p_PNAME_NS) {
	m_PNAME_NS = p_PNAME_NS;
	trace("PrefixedName", 1, p_PNAME_NS);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_PNAME_NS);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_PNAME_NS);}
};
class BlankNode : public _Production {
private:
    virtual const char * getProductionName () { return "BlankNode"; }
};
class BlankNode_rule0 : public BlankNode {
private:
    BLANK_NODE_LABEL* m_BLANK_NODE_LABEL;
public:
    BlankNode_rule0 (BLANK_NODE_LABEL* p_BLANK_NODE_LABEL) {
	m_BLANK_NODE_LABEL = p_BLANK_NODE_LABEL;
	trace("BlankNode", 1, p_BLANK_NODE_LABEL);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_BLANK_NODE_LABEL);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_BLANK_NODE_LABEL);}
};
class BlankNode_rule1 : public BlankNode {
private:
    ANON* m_ANON;
public:
    BlankNode_rule1 (ANON* p_ANON) {
	m_ANON = p_ANON;
	trace("BlankNode", 1, p_ANON);
    }
    virtual const char* toStr (std::ofstream* out = NULL) {return _Production::toStr(out, 1, m_ANON);}
    virtual const char* toXml (size_t depth, std::ofstream* out = NULL) {return _Production::toXml(depth, out, 1, m_ANON);}
};

class IT_BASE : public _Token {
public:
    IT_BASE() { trace(); }
    virtual const char * getProductionName () { return "IT_BASE"; }
    virtual const char * getToken() { return "BASE"; }
};
class IT_PREFIX : public _Token {
public:
    IT_PREFIX() { trace(); }
    virtual const char * getProductionName () { return "IT_PREFIX"; }
    virtual const char * getToken() { return "PREFIX"; }
};
class IT_SELECT : public _Token {
public:
    IT_SELECT() { trace(); }
    virtual const char * getProductionName () { return "IT_SELECT"; }
    virtual const char * getToken() { return "SELECT"; }
};
class IT_DISTINCT : public _Token {
public:
    IT_DISTINCT() { trace(); }
    virtual const char * getProductionName () { return "IT_DISTINCT"; }
    virtual const char * getToken() { return "DISTINCT"; }
};
class IT_REDUCED : public _Token {
public:
    IT_REDUCED() { trace(); }
    virtual const char * getProductionName () { return "IT_REDUCED"; }
    virtual const char * getToken() { return "REDUCED"; }
};
class GT_TIMES : public _Token {
public:
    GT_TIMES() { trace(); }
    virtual const char * getProductionName () { return "GT_TIMES"; }
    virtual const char * getToken() { return "TIMES"; }
};
class IT_CONSTRUCT : public _Token {
public:
    IT_CONSTRUCT() { trace(); }
    virtual const char * getProductionName () { return "IT_CONSTRUCT"; }
    virtual const char * getToken() { return "CONSTRUCT"; }
};
class IT_DESCRIBE : public _Token {
public:
    IT_DESCRIBE() { trace(); }
    virtual const char * getProductionName () { return "IT_DESCRIBE"; }
    virtual const char * getToken() { return "DESCRIBE"; }
};
class IT_ASK : public _Token {
public:
    IT_ASK() { trace(); }
    virtual const char * getProductionName () { return "IT_ASK"; }
    virtual const char * getToken() { return "ASK"; }
};
class IT_FROM : public _Token {
public:
    IT_FROM() { trace(); }
    virtual const char * getProductionName () { return "IT_FROM"; }
    virtual const char * getToken() { return "FROM"; }
};
class IT_NAMED : public _Token {
public:
    IT_NAMED() { trace(); }
    virtual const char * getProductionName () { return "IT_NAMED"; }
    virtual const char * getToken() { return "NAMED"; }
};
class IT_WHERE : public _Token {
public:
    IT_WHERE() { trace(); }
    virtual const char * getProductionName () { return "IT_WHERE"; }
    virtual const char * getToken() { return "WHERE"; }
};
class IT_ORDER : public _Token {
public:
    IT_ORDER() { trace(); }
    virtual const char * getProductionName () { return "IT_ORDER"; }
    virtual const char * getToken() { return "ORDER"; }
};
class IT_BY : public _Token {
public:
    IT_BY() { trace(); }
    virtual const char * getProductionName () { return "IT_BY"; }
    virtual const char * getToken() { return "BY"; }
};
class IT_ASC : public _Token {
public:
    IT_ASC() { trace(); }
    virtual const char * getProductionName () { return "IT_ASC"; }
    virtual const char * getToken() { return "ASC"; }
};
class IT_DESC : public _Token {
public:
    IT_DESC() { trace(); }
    virtual const char * getProductionName () { return "IT_DESC"; }
    virtual const char * getToken() { return "DESC"; }
};
class IT_LIMIT : public _Token {
public:
    IT_LIMIT() { trace(); }
    virtual const char * getProductionName () { return "IT_LIMIT"; }
    virtual const char * getToken() { return "LIMIT"; }
};
class IT_OFFSET : public _Token {
public:
    IT_OFFSET() { trace(); }
    virtual const char * getProductionName () { return "IT_OFFSET"; }
    virtual const char * getToken() { return "OFFSET"; }
};
class GT_LCURLEY : public _Token {
public:
    GT_LCURLEY() { trace(); }
    virtual const char * getProductionName () { return "GT_LCURLEY"; }
    virtual const char * getToken() { return "LCURLEY"; }
};
class GT_RCURLEY : public _Token {
public:
    GT_RCURLEY() { trace(); }
    virtual const char * getProductionName () { return "GT_RCURLEY"; }
    virtual const char * getToken() { return "RCURLEY"; }
};
class GT_DOT : public _Token {
public:
    GT_DOT() { trace(); }
    virtual const char * getProductionName () { return "GT_DOT"; }
    virtual const char * getToken() { return "DOT"; }
};
class IT_OPTIONAL : public _Token {
public:
    IT_OPTIONAL() { trace(); }
    virtual const char * getProductionName () { return "IT_OPTIONAL"; }
    virtual const char * getToken() { return "OPTIONAL"; }
};
class IT_GRAPH : public _Token {
public:
    IT_GRAPH() { trace(); }
    virtual const char * getProductionName () { return "IT_GRAPH"; }
    virtual const char * getToken() { return "GRAPH"; }
};
class IT_UNION : public _Token {
public:
    IT_UNION() { trace(); }
    virtual const char * getProductionName () { return "IT_UNION"; }
    virtual const char * getToken() { return "UNION"; }
};
class IT_FILTER : public _Token {
public:
    IT_FILTER() { trace(); }
    virtual const char * getProductionName () { return "IT_FILTER"; }
    virtual const char * getToken() { return "FILTER"; }
};
class GT_COMMA : public _Token {
public:
    GT_COMMA() { trace(); }
    virtual const char * getProductionName () { return "GT_COMMA"; }
    virtual const char * getToken() { return "COMMA"; }
};
class GT_LPAREN : public _Token {
public:
    GT_LPAREN() { trace(); }
    virtual const char * getProductionName () { return "GT_LPAREN"; }
    virtual const char * getToken() { return "LPAREN"; }
};
class GT_RPAREN : public _Token {
public:
    GT_RPAREN() { trace(); }
    virtual const char * getProductionName () { return "GT_RPAREN"; }
    virtual const char * getToken() { return "RPAREN"; }
};
class GT_SEMI : public _Token {
public:
    GT_SEMI() { trace(); }
    virtual const char * getProductionName () { return "GT_SEMI"; }
    virtual const char * getToken() { return "SEMI"; }
};
class IT_a : public _Token {
public:
    IT_a() { trace(); }
    virtual const char * getProductionName () { return "IT_a"; }
    virtual const char * getToken() { return "a"; }
};
class GT_LBRACKET : public _Token {
public:
    GT_LBRACKET() { trace(); }
    virtual const char * getProductionName () { return "GT_LBRACKET"; }
    virtual const char * getToken() { return "LBRACKET"; }
};
class GT_RBRACKET : public _Token {
public:
    GT_RBRACKET() { trace(); }
    virtual const char * getProductionName () { return "GT_RBRACKET"; }
    virtual const char * getToken() { return "RBRACKET"; }
};
class GT_OR : public _Token {
public:
    GT_OR() { trace(); }
    virtual const char * getProductionName () { return "GT_OR"; }
    virtual const char * getToken() { return "OR"; }
};
class GT_AND : public _Token {
public:
    GT_AND() { trace(); }
    virtual const char * getProductionName () { return "GT_AND"; }
    virtual const char * getToken() { return "AND"; }
};
class GT_EQUAL : public _Token {
public:
    GT_EQUAL() { trace(); }
    virtual const char * getProductionName () { return "GT_EQUAL"; }
    virtual const char * getToken() { return "EQUAL"; }
};
class GT_NEQUAL : public _Token {
public:
    GT_NEQUAL() { trace(); }
    virtual const char * getProductionName () { return "GT_NEQUAL"; }
    virtual const char * getToken() { return "NEQUAL"; }
};
class GT_LT : public _Token {
public:
    GT_LT() { trace(); }
    virtual const char * getProductionName () { return "GT_LT"; }
    virtual const char * getToken() { return "LT"; }
};
class GT_GT : public _Token {
public:
    GT_GT() { trace(); }
    virtual const char * getProductionName () { return "GT_GT"; }
    virtual const char * getToken() { return "GT"; }
};
class GT_LE : public _Token {
public:
    GT_LE() { trace(); }
    virtual const char * getProductionName () { return "GT_LE"; }
    virtual const char * getToken() { return "LE"; }
};
class GT_GE : public _Token {
public:
    GT_GE() { trace(); }
    virtual const char * getProductionName () { return "GT_GE"; }
    virtual const char * getToken() { return "GE"; }
};
class GT_PLUS : public _Token {
public:
    GT_PLUS() { trace(); }
    virtual const char * getProductionName () { return "GT_PLUS"; }
    virtual const char * getToken() { return "PLUS"; }
};
class GT_MINUS : public _Token {
public:
    GT_MINUS() { trace(); }
    virtual const char * getProductionName () { return "GT_MINUS"; }
    virtual const char * getToken() { return "MINUS"; }
};
class GT_DIVIDE : public _Token {
public:
    GT_DIVIDE() { trace(); }
    virtual const char * getProductionName () { return "GT_DIVIDE"; }
    virtual const char * getToken() { return "DIVIDE"; }
};
class GT_NOT : public _Token {
public:
    GT_NOT() { trace(); }
    virtual const char * getProductionName () { return "GT_NOT"; }
    virtual const char * getToken() { return "NOT"; }
};
class IT_STR : public _Token {
public:
    IT_STR() { trace(); }
    virtual const char * getProductionName () { return "IT_STR"; }
    virtual const char * getToken() { return "STR"; }
};
class IT_LANG : public _Token {
public:
    IT_LANG() { trace(); }
    virtual const char * getProductionName () { return "IT_LANG"; }
    virtual const char * getToken() { return "LANG"; }
};
class IT_LANGMATCHES : public _Token {
public:
    IT_LANGMATCHES() { trace(); }
    virtual const char * getProductionName () { return "IT_LANGMATCHES"; }
    virtual const char * getToken() { return "LANGMATCHES"; }
};
class IT_DATATYPE : public _Token {
public:
    IT_DATATYPE() { trace(); }
    virtual const char * getProductionName () { return "IT_DATATYPE"; }
    virtual const char * getToken() { return "DATATYPE"; }
};
class IT_BOUND : public _Token {
public:
    IT_BOUND() { trace(); }
    virtual const char * getProductionName () { return "IT_BOUND"; }
    virtual const char * getToken() { return "BOUND"; }
};
class IT_sameTerm : public _Token {
public:
    IT_sameTerm() { trace(); }
    virtual const char * getProductionName () { return "IT_sameTerm"; }
    virtual const char * getToken() { return "sameTerm"; }
};
class IT_isIRI : public _Token {
public:
    IT_isIRI() { trace(); }
    virtual const char * getProductionName () { return "IT_isIRI"; }
    virtual const char * getToken() { return "isIRI"; }
};
class IT_isURI : public _Token {
public:
    IT_isURI() { trace(); }
    virtual const char * getProductionName () { return "IT_isURI"; }
    virtual const char * getToken() { return "isURI"; }
};
class IT_isBLANK : public _Token {
public:
    IT_isBLANK() { trace(); }
    virtual const char * getProductionName () { return "IT_isBLANK"; }
    virtual const char * getToken() { return "isBLANK"; }
};
class IT_isLITERAL : public _Token {
public:
    IT_isLITERAL() { trace(); }
    virtual const char * getProductionName () { return "IT_isLITERAL"; }
    virtual const char * getToken() { return "isLITERAL"; }
};
class IT_REGEX : public _Token {
public:
    IT_REGEX() { trace(); }
    virtual const char * getProductionName () { return "IT_REGEX"; }
    virtual const char * getToken() { return "REGEX"; }
};
class GT_DTYPE : public _Token {
public:
    GT_DTYPE() { trace(); }
    virtual const char * getProductionName () { return "GT_DTYPE"; }
    virtual const char * getToken() { return "DTYPE"; }
};
class IT_true : public _Token {
public:
    IT_true() { trace(); }
    virtual const char * getProductionName () { return "IT_true"; }
    virtual const char * getToken() { return "true"; }
};
class IT_false : public _Token {
public:
    IT_false() { trace(); }
    virtual const char * getProductionName () { return "IT_false"; }
    virtual const char * getToken() { return "false"; }
};
class IRI_REF : public _Terminal {
private:
    virtual const char * getProductionName () { return "IRI_REF"; }
public:
    IRI_REF(const char * p_IRI_REF) : _Terminal(p_IRI_REF) { trace(); }
};
class PNAME_NS : public _Terminal {
private:
    virtual const char * getProductionName () { return "PNAME_NS"; }
public:
    PNAME_NS(const char * p_PNAME_NS) : _Terminal(p_PNAME_NS) { trace(); }
};
class PNAME_LN : public _Terminal {
private:
    virtual const char * getProductionName () { return "PNAME_LN"; }
public:
    PNAME_LN(const char * p_PNAME_LN) : _Terminal(p_PNAME_LN) { trace(); }
};
class BLANK_NODE_LABEL : public _Terminal {
private:
    virtual const char * getProductionName () { return "BLANK_NODE_LABEL"; }
public:
    BLANK_NODE_LABEL(const char * p_BLANK_NODE_LABEL) : _Terminal(p_BLANK_NODE_LABEL) { trace(); }
};
class VAR1 : public _Terminal {
private:
    virtual const char * getProductionName () { return "VAR1"; }
public:
    VAR1(const char * p_VAR1) : _Terminal(p_VAR1) { trace(); }
};
class VAR2 : public _Terminal {
private:
    virtual const char * getProductionName () { return "VAR2"; }
public:
    VAR2(const char * p_VAR2) : _Terminal(p_VAR2) { trace(); }
};
class LANGTAG : public _Terminal {
private:
    virtual const char * getProductionName () { return "LANGTAG"; }
public:
    LANGTAG(const char * p_LANGTAG) : _Terminal(p_LANGTAG) { trace(); }
};
class INTEGER : public _Terminal {
private:
    virtual const char * getProductionName () { return "INTEGER"; }
public:
    INTEGER(const char * p_INTEGER) : _Terminal(p_INTEGER) { trace(); }
};
class DECIMAL : public _Terminal {
private:
    virtual const char * getProductionName () { return "DECIMAL"; }
public:
    DECIMAL(const char * p_DECIMAL) : _Terminal(p_DECIMAL) { trace(); }
};
class DOUBLE : public _Terminal {
private:
    virtual const char * getProductionName () { return "DOUBLE"; }
public:
    DOUBLE(const char * p_DOUBLE) : _Terminal(p_DOUBLE) { trace(); }
};
class INTEGER_POSITIVE : public _Terminal {
private:
    virtual const char * getProductionName () { return "INTEGER_POSITIVE"; }
public:
    INTEGER_POSITIVE(const char * p_INTEGER_POSITIVE) : _Terminal(p_INTEGER_POSITIVE) { trace(); }
};
class DECIMAL_POSITIVE : public _Terminal {
private:
    virtual const char * getProductionName () { return "DECIMAL_POSITIVE"; }
public:
    DECIMAL_POSITIVE(const char * p_DECIMAL_POSITIVE) : _Terminal(p_DECIMAL_POSITIVE) { trace(); }
};
class DOUBLE_POSITIVE : public _Terminal {
private:
    virtual const char * getProductionName () { return "DOUBLE_POSITIVE"; }
public:
    DOUBLE_POSITIVE(const char * p_DOUBLE_POSITIVE) : _Terminal(p_DOUBLE_POSITIVE) { trace(); }
};
class INTEGER_NEGATIVE : public _Terminal {
private:
    virtual const char * getProductionName () { return "INTEGER_NEGATIVE"; }
public:
    INTEGER_NEGATIVE(const char * p_INTEGER_NEGATIVE) : _Terminal(p_INTEGER_NEGATIVE) { trace(); }
};
class DECIMAL_NEGATIVE : public _Terminal {
private:
    virtual const char * getProductionName () { return "DECIMAL_NEGATIVE"; }
public:
    DECIMAL_NEGATIVE(const char * p_DECIMAL_NEGATIVE) : _Terminal(p_DECIMAL_NEGATIVE) { trace(); }
};
class DOUBLE_NEGATIVE : public _Terminal {
private:
    virtual const char * getProductionName () { return "DOUBLE_NEGATIVE"; }
public:
    DOUBLE_NEGATIVE(const char * p_DOUBLE_NEGATIVE) : _Terminal(p_DOUBLE_NEGATIVE) { trace(); }
};
class STRING_LITERAL1 : public _Terminal {
private:
    virtual const char * getProductionName () { return "STRING_LITERAL1"; }
public:
    STRING_LITERAL1(const char * p_STRING_LITERAL1) : _Terminal(p_STRING_LITERAL1) { trace(); }
};
class STRING_LITERAL2 : public _Terminal {
private:
    virtual const char * getProductionName () { return "STRING_LITERAL2"; }
public:
    STRING_LITERAL2(const char * p_STRING_LITERAL2) : _Terminal(p_STRING_LITERAL2) { trace(); }
};
class STRING_LITERAL_LONG1 : public _Terminal {
private:
    virtual const char * getProductionName () { return "STRING_LITERAL_LONG1"; }
public:
    STRING_LITERAL_LONG1(const char * p_STRING_LITERAL_LONG1) : _Terminal(p_STRING_LITERAL_LONG1) { trace(); }
};
class STRING_LITERAL_LONG2 : public _Terminal {
private:
    virtual const char * getProductionName () { return "STRING_LITERAL_LONG2"; }
public:
    STRING_LITERAL_LONG2(const char * p_STRING_LITERAL_LONG2) : _Terminal(p_STRING_LITERAL_LONG2) { trace(); }
};
class NIL : public _Terminal {
private:
    virtual const char * getProductionName () { return "NIL"; }
public:
    NIL(const char * p_NIL) : _Terminal(p_NIL) { trace(); }
};
class ANON : public _Terminal {
private:
    virtual const char * getProductionName () { return "ANON"; }
public:
    ANON(const char * p_ANON) : _Terminal(p_ANON) { trace(); }
};

/* END ClassBlock */

extern Query* StupidGlobal;

namespace SPARQLNS {

/** The Driver class brings together all components. It creates an instance of
 * the SPARQLParser and SPARQLScanner classes and connects them. Then the input stream is
 * fed into the scanner object and the parser gets it's token
 * sequence. Furthermore the driver object is available in the grammar rules as
 * a parameter. Therefore the driver class contains a reference to the
 * structure into which the parsed data is saved. */
class SPARQLContext {
public:
    ~SPARQLContext()
    {
    }
};

class Driver
{
public:
    /// construct a new parser driver context
    Driver(SPARQLContext& context);

    /// enable debug output in the flex scanner
    bool trace_scanning;

    /// enable debug output in the bison parser
    bool trace_parsing;

    /// stream name (file or input stream) used for error messages.
    std::string streamname;

    /** Invoke the scanner and parser for a stream.
     * @param in	input stream
     * @param sname	stream name for error messages
     * @return		true if successfully parsed
     */
    bool parse_stream(std::istream& in,
		      const std::string& sname = "stream input");

    /** Invoke the scanner and parser on an input string.
     * @param input	input string
     * @param sname	stream name for error messages
     * @return		true if successfully parsed
     */
    bool parse_string(const std::string& input,
		      const std::string& sname = "string stream");

    /** Invoke the scanner and parser on a file. Use parse_stream with a
     * std::ifstream if detection of file reading errors is required.
     * @param filename	input file name
     * @return		true if successfully parsed
     */
    bool parse_file(const std::string& filename);

    // To demonstrate pure handling of parse errors, instead of
    // simply dumping them on the standard error output, we will pass
    // them to the driver using the following two member functions.

    /** Error handling with associated line number. This can be modified to
     * output the error e.g. to a dialog box. */
    void error(const class location& l, const std::string& m);

    /** General error handling. This can be modified to output the error
     * e.g. to a dialog box. */
    void error(const std::string& m);

    /** Pointer to the current lexer instance, this is used to connect the
     * parser to the scanner. It is used in the yylex macro. */
    class SPARQLScanner* lexer;

    /** Reference to the context filled during parsing of the expressions. */
    SPARQLContext& context;
};

} // namespace SPARQLNS



/* Line 35 of lalr1.cc.  */
#line 4020 "SPARQLParser.hh"

#include "location.hh"

/* Enabling traces.  */
#ifndef YYDEBUG
# define YYDEBUG 1
#endif

/* Enabling verbose error messages.  */
#ifdef YYERROR_VERBOSE
# undef YYERROR_VERBOSE
# define YYERROR_VERBOSE 1
#else
# define YYERROR_VERBOSE 1
#endif

/* Enabling the token table.  */
#ifndef YYTOKEN_TABLE
# define YYTOKEN_TABLE 0
#endif

/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

#ifndef YYLLOC_DEFAULT
# define YYLLOC_DEFAULT(Current, Rhs, N)		\
do {							\
  if (N)						\
    {							\
      (Current).begin = (Rhs)[1].begin;			\
      (Current).end   = (Rhs)[N].end;			\
    }							\
  else							\
    {							\
      (Current).begin = (Current).end = (Rhs)[0].end;	\
    }							\
} while (false)
#endif

namespace SPARQLNS
{

  /// A Bison parser.
  class SPARQLParser
  {
  public:
    /// Symbol semantic values.
#ifndef YYSTYPE
    union semantic_type
#line 4012 "SPARQLParser.yy"
{
    /* Terminals */
    IT_BASE* p_IT_BASE;
    IT_PREFIX* p_IT_PREFIX;
    IT_SELECT* p_IT_SELECT;
    IT_DISTINCT* p_IT_DISTINCT;
    IT_REDUCED* p_IT_REDUCED;
    GT_TIMES* p_GT_TIMES;
    IT_CONSTRUCT* p_IT_CONSTRUCT;
    IT_DESCRIBE* p_IT_DESCRIBE;
    IT_ASK* p_IT_ASK;
    IT_FROM* p_IT_FROM;
    IT_NAMED* p_IT_NAMED;
    IT_WHERE* p_IT_WHERE;
    IT_ORDER* p_IT_ORDER;
    IT_BY* p_IT_BY;
    IT_ASC* p_IT_ASC;
    IT_DESC* p_IT_DESC;
    IT_LIMIT* p_IT_LIMIT;
    IT_OFFSET* p_IT_OFFSET;
    GT_LCURLEY* p_GT_LCURLEY;
    GT_RCURLEY* p_GT_RCURLEY;
    GT_DOT* p_GT_DOT;
    IT_OPTIONAL* p_IT_OPTIONAL;
    IT_GRAPH* p_IT_GRAPH;
    IT_UNION* p_IT_UNION;
    IT_FILTER* p_IT_FILTER;
    GT_COMMA* p_GT_COMMA;
    GT_LPAREN* p_GT_LPAREN;
    GT_RPAREN* p_GT_RPAREN;
    GT_SEMI* p_GT_SEMI;
    IT_a* p_IT_a;
    GT_LBRACKET* p_GT_LBRACKET;
    GT_RBRACKET* p_GT_RBRACKET;
    GT_OR* p_GT_OR;
    GT_AND* p_GT_AND;
    GT_EQUAL* p_GT_EQUAL;
    GT_NEQUAL* p_GT_NEQUAL;
    GT_LT* p_GT_LT;
    GT_GT* p_GT_GT;
    GT_LE* p_GT_LE;
    GT_GE* p_GT_GE;
    GT_PLUS* p_GT_PLUS;
    GT_MINUS* p_GT_MINUS;
    GT_DIVIDE* p_GT_DIVIDE;
    GT_NOT* p_GT_NOT;
    IT_STR* p_IT_STR;
    IT_LANG* p_IT_LANG;
    IT_LANGMATCHES* p_IT_LANGMATCHES;
    IT_DATATYPE* p_IT_DATATYPE;
    IT_BOUND* p_IT_BOUND;
    IT_sameTerm* p_IT_sameTerm;
    IT_isIRI* p_IT_isIRI;
    IT_isURI* p_IT_isURI;
    IT_isBLANK* p_IT_isBLANK;
    IT_isLITERAL* p_IT_isLITERAL;
    IT_REGEX* p_IT_REGEX;
    GT_DTYPE* p_GT_DTYPE;
    IT_true* p_IT_true;
    IT_false* p_IT_false;
    IRI_REF* p_IRI_REF;
    PNAME_NS* p_PNAME_NS;
    PNAME_LN* p_PNAME_LN;
    BLANK_NODE_LABEL* p_BLANK_NODE_LABEL;
    VAR1* p_VAR1;
    VAR2* p_VAR2;
    LANGTAG* p_LANGTAG;
    INTEGER* p_INTEGER;
    DECIMAL* p_DECIMAL;
    DOUBLE* p_DOUBLE;
    INTEGER_POSITIVE* p_INTEGER_POSITIVE;
    DECIMAL_POSITIVE* p_DECIMAL_POSITIVE;
    DOUBLE_POSITIVE* p_DOUBLE_POSITIVE;
    INTEGER_NEGATIVE* p_INTEGER_NEGATIVE;
    DECIMAL_NEGATIVE* p_DECIMAL_NEGATIVE;
    DOUBLE_NEGATIVE* p_DOUBLE_NEGATIVE;
    STRING_LITERAL1* p_STRING_LITERAL1;
    STRING_LITERAL2* p_STRING_LITERAL2;
    STRING_LITERAL_LONG1* p_STRING_LITERAL_LONG1;
    STRING_LITERAL_LONG2* p_STRING_LITERAL_LONG2;
    NIL* p_NIL;
    ANON* p_ANON;

    /* Productions */
    Query* p_Query;
    _O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C* p__O_QSelectQuery_E_Or_QConstructQuery_E_Or_QDescribeQuery_E_Or_QAskQuery_E_C;
    Prologue* p_Prologue;
    _QBaseDecl_E_Opt* p__QBaseDecl_E_Opt;
    _QPrefixDecl_E_Star* p__QPrefixDecl_E_Star;
    BaseDecl* p_BaseDecl;
    PrefixDecl* p_PrefixDecl;
    SelectQuery* p_SelectQuery;
    _O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C* p__O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C;
    _Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt* p__Q_O_QIT_DISTINCT_E_Or_QIT_REDUCED_E_C_E_Opt;
    _QVar_E_Plus* p__QVar_E_Plus;
    _O_QVar_E_Plus_Or_QGT_TIMES_E_C* p__O_QVar_E_Plus_Or_QGT_TIMES_E_C;
    _QDatasetClause_E_Star* p__QDatasetClause_E_Star;
    ConstructQuery* p_ConstructQuery;
    DescribeQuery* p_DescribeQuery;
    _QVarOrIRIref_E_Plus* p__QVarOrIRIref_E_Plus;
    _O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C* p__O_QVarOrIRIref_E_Plus_Or_QGT_TIMES_E_C;
    _QWhereClause_E_Opt* p__QWhereClause_E_Opt;
    AskQuery* p_AskQuery;
    DatasetClause* p_DatasetClause;
    _O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C* p__O_QDefaultGraphClause_E_Or_QNamedGraphClause_E_C;
    DefaultGraphClause* p_DefaultGraphClause;
    NamedGraphClause* p_NamedGraphClause;
    SourceSelector* p_SourceSelector;
    WhereClause* p_WhereClause;
    _QIT_WHERE_E_Opt* p__QIT_WHERE_E_Opt;
    SolutionModifier* p_SolutionModifier;
    _QOrderClause_E_Opt* p__QOrderClause_E_Opt;
    _QLimitOffsetClauses_E_Opt* p__QLimitOffsetClauses_E_Opt;
    LimitOffsetClauses* p_LimitOffsetClauses;
    _QOffsetClause_E_Opt* p__QOffsetClause_E_Opt;
    _QLimitClause_E_Opt* p__QLimitClause_E_Opt;
    _O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C* p__O_QLimitClause_E_S_QOffsetClause_E_Opt_Or_QOffsetClause_E_S_QLimitClause_E_Opt_C;
    OrderClause* p_OrderClause;
    _QOrderCondition_E_Plus* p__QOrderCondition_E_Plus;
    OrderCondition* p_OrderCondition;
    _O_QIT_ASC_E_Or_QIT_DESC_E_C* p__O_QIT_ASC_E_Or_QIT_DESC_E_C;
    _O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C* p__O_QIT_ASC_E_Or_QIT_DESC_E_S_QBrackettedExpression_E_C;
    _O_QConstraint_E_Or_QVar_E_C* p__O_QConstraint_E_Or_QVar_E_C;
    LimitClause* p_LimitClause;
    OffsetClause* p_OffsetClause;
    GroupGraphPattern* p_GroupGraphPattern;
    _QTriplesBlock_E_Opt* p__QTriplesBlock_E_Opt;
    _O_QGraphPatternNotTriples_E_Or_QFilter_E_C* p__O_QGraphPatternNotTriples_E_Or_QFilter_E_C;
    _QGT_DOT_E_Opt* p__QGT_DOT_E_Opt;
    _O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C* p__O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C;
    _Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star* p__Q_O_QGraphPatternNotTriples_E_Or_QFilter_E_S_QGT_DOT_E_Opt_S_QTriplesBlock_E_Opt_C_E_Star;
    TriplesBlock* p_TriplesBlock;
    _O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C* p__O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C;
    _Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt* p__Q_O_QGT_DOT_E_S_QTriplesBlock_E_Opt_C_E_Opt;
    GraphPatternNotTriples* p_GraphPatternNotTriples;
    OptionalGraphPattern* p_OptionalGraphPattern;
    GraphGraphPattern* p_GraphGraphPattern;
    GroupOrUnionGraphPattern* p_GroupOrUnionGraphPattern;
    _O_QIT_UNION_E_S_QGroupGraphPattern_E_C* p__O_QIT_UNION_E_S_QGroupGraphPattern_E_C;
    _Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star* p__Q_O_QIT_UNION_E_S_QGroupGraphPattern_E_C_E_Star;
    Filter* p_Filter;
    Constraint* p_Constraint;
    FunctionCall* p_FunctionCall;
    ArgList* p_ArgList;
    _O_QGT_COMMA_E_S_QExpression_E_C* p__O_QGT_COMMA_E_S_QExpression_E_C;
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Star;
    _O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C* p__O_QNIL_E_Or_QGT_LPAREN_E_S_QExpression_E_S_QGT_COMMA_E_S_QExpression_E_Star_S_QGT_RPAREN_E_C;
    ConstructTemplate* p_ConstructTemplate;
    _QConstructTriples_E_Opt* p__QConstructTriples_E_Opt;
    ConstructTriples* p_ConstructTriples;
    _O_QGT_DOT_E_S_QConstructTriples_E_Opt_C* p__O_QGT_DOT_E_S_QConstructTriples_E_Opt_C;
    _Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt* p__Q_O_QGT_DOT_E_S_QConstructTriples_E_Opt_C_E_Opt;
    TriplesSameSubject* p_TriplesSameSubject;
    PropertyListNotEmpty* p_PropertyListNotEmpty;
    _O_QVerb_E_S_QObjectList_E_C* p__O_QVerb_E_S_QObjectList_E_C;
    _Q_O_QVerb_E_S_QObjectList_E_C_E_Opt* p__Q_O_QVerb_E_S_QObjectList_E_C_E_Opt;
    _O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C* p__O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C;
    _Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star* p__Q_O_QGT_SEMI_E_S_QVerb_E_S_QObjectList_E_Opt_C_E_Star;
    PropertyList* p_PropertyList;
    _QPropertyListNotEmpty_E_Opt* p__QPropertyListNotEmpty_E_Opt;
    ObjectList* p_ObjectList;
    _O_QGT_COMMA_E_S_QObject_E_C* p__O_QGT_COMMA_E_S_QObject_E_C;
    _Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star* p__Q_O_QGT_COMMA_E_S_QObject_E_C_E_Star;
    Object* p_Object;
    Verb* p_Verb;
    TriplesNode* p_TriplesNode;
    BlankNodePropertyList* p_BlankNodePropertyList;
    Collection* p_Collection;
    _QGraphNode_E_Plus* p__QGraphNode_E_Plus;
    GraphNode* p_GraphNode;
    VarOrTerm* p_VarOrTerm;
    VarOrIRIref* p_VarOrIRIref;
    Var* p_Var;
    GraphTerm* p_GraphTerm;
    Expression* p_Expression;
    ConditionalOrExpression* p_ConditionalOrExpression;
    _O_QGT_OR_E_S_QConditionalAndExpression_E_C* p__O_QGT_OR_E_S_QConditionalAndExpression_E_C;
    _Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star* p__Q_O_QGT_OR_E_S_QConditionalAndExpression_E_C_E_Star;
    ConditionalAndExpression* p_ConditionalAndExpression;
    _O_QGT_AND_E_S_QValueLogical_E_C* p__O_QGT_AND_E_S_QValueLogical_E_C;
    _Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star* p__Q_O_QGT_AND_E_S_QValueLogical_E_C_E_Star;
    ValueLogical* p_ValueLogical;
    RelationalExpression* p_RelationalExpression;
    _O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C* p__O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C;
    _Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt* p__Q_O_QGT_EQUAL_E_S_QNumericExpression_E_Or_QGT_NEQUAL_E_S_QNumericExpression_E_Or_QGT_LT_E_S_QNumericExpression_E_Or_QGT_GT_E_S_QNumericExpression_E_Or_QGT_LE_E_S_QNumericExpression_E_Or_QGT_GE_E_S_QNumericExpression_E_C_E_Opt;
    NumericExpression* p_NumericExpression;
    AdditiveExpression* p_AdditiveExpression;
    _O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C* p__O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C;
    _Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star* p__Q_O_QGT_PLUS_E_S_QMultiplicativeExpression_E_Or_QGT_MINUS_E_S_QMultiplicativeExpression_E_Or_QNumericLiteralPositive_E_Or_QNumericLiteralNegative_E_C_E_Star;
    MultiplicativeExpression* p_MultiplicativeExpression;
    _O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C* p__O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C;
    _Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star* p__Q_O_QGT_TIMES_E_S_QUnaryExpression_E_Or_QGT_DIVIDE_E_S_QUnaryExpression_E_C_E_Star;
    UnaryExpression* p_UnaryExpression;
    PrimaryExpression* p_PrimaryExpression;
    BrackettedExpression* p_BrackettedExpression;
    BuiltInCall* p_BuiltInCall;
    RegexExpression* p_RegexExpression;
    _Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt* p__Q_O_QGT_COMMA_E_S_QExpression_E_C_E_Opt;
    IRIrefOrFunction* p_IRIrefOrFunction;
    _QArgList_E_Opt* p__QArgList_E_Opt;
    RDFLiteral* p_RDFLiteral;
    _O_QGT_DTYPE_E_S_QIRIref_E_C* p__O_QGT_DTYPE_E_S_QIRIref_E_C;
    _O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C* p__O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C;
    _Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt* p__Q_O_QLANGTAG_E_Or_QGT_DTYPE_E_S_QIRIref_E_C_E_Opt;
    NumericLiteral* p_NumericLiteral;
    NumericLiteralUnsigned* p_NumericLiteralUnsigned;
    NumericLiteralPositive* p_NumericLiteralPositive;
    NumericLiteralNegative* p_NumericLiteralNegative;
    BooleanLiteral* p_BooleanLiteral;
    String* p_String;
    IRIref* p_IRIref;
    PrefixedName* p_PrefixedName;
    BlankNode* p_BlankNode;

}
/* Line 35 of lalr1.cc.  */
#line 4288 "SPARQLParser.hh"
	;
#else
    typedef YYSTYPE semantic_type;
#endif
    /// Symbol locations.
    typedef location location_type;
    /// Tokens.
    struct token
    {
      /* Tokens.  */
   enum yytokentype {
     __EOF__ = 0,
     IT_BASE = 258,
     IT_PREFIX = 259,
     IT_SELECT = 260,
     IT_DISTINCT = 261,
     IT_REDUCED = 262,
     GT_TIMES = 263,
     IT_CONSTRUCT = 264,
     IT_DESCRIBE = 265,
     IT_ASK = 266,
     IT_FROM = 267,
     IT_NAMED = 268,
     IT_WHERE = 269,
     IT_ORDER = 270,
     IT_BY = 271,
     IT_ASC = 272,
     IT_DESC = 273,
     IT_LIMIT = 274,
     IT_OFFSET = 275,
     GT_LCURLEY = 276,
     GT_RCURLEY = 277,
     GT_DOT = 278,
     IT_OPTIONAL = 279,
     IT_GRAPH = 280,
     IT_UNION = 281,
     IT_FILTER = 282,
     GT_COMMA = 283,
     GT_LPAREN = 284,
     GT_RPAREN = 285,
     GT_SEMI = 286,
     IT_a = 287,
     GT_LBRACKET = 288,
     GT_RBRACKET = 289,
     GT_OR = 290,
     GT_AND = 291,
     GT_EQUAL = 292,
     GT_NEQUAL = 293,
     GT_LT = 294,
     GT_GT = 295,
     GT_LE = 296,
     GT_GE = 297,
     GT_PLUS = 298,
     GT_MINUS = 299,
     GT_DIVIDE = 300,
     GT_NOT = 301,
     IT_STR = 302,
     IT_LANG = 303,
     IT_LANGMATCHES = 304,
     IT_DATATYPE = 305,
     IT_BOUND = 306,
     IT_sameTerm = 307,
     IT_isIRI = 308,
     IT_isURI = 309,
     IT_isBLANK = 310,
     IT_isLITERAL = 311,
     IT_REGEX = 312,
     GT_DTYPE = 313,
     IT_true = 314,
     IT_false = 315,
     IRI_REF = 316,
     PNAME_NS = 317,
     PNAME_LN = 318,
     BLANK_NODE_LABEL = 319,
     VAR1 = 320,
     VAR2 = 321,
     LANGTAG = 322,
     INTEGER = 323,
     DECIMAL = 324,
     DOUBLE = 325,
     INTEGER_POSITIVE = 326,
     DECIMAL_POSITIVE = 327,
     DOUBLE_POSITIVE = 328,
     INTEGER_NEGATIVE = 329,
     DECIMAL_NEGATIVE = 330,
     DOUBLE_NEGATIVE = 331,
     STRING_LITERAL1 = 332,
     STRING_LITERAL2 = 333,
     STRING_LITERAL_LONG1 = 334,
     STRING_LITERAL_LONG2 = 335,
     NIL = 336,
     ANON = 337
   };

    };
    /// Token type.
    typedef token::yytokentype token_type;

    /// Build a parser object.
    SPARQLParser (class Driver& driver_yyarg);
    virtual ~SPARQLParser ();

    /// Parse.
    /// \returns  0 iff parsing succeeded.
    virtual int parse ();

    /// The current debugging stream.
    std::ostream& debug_stream () const;
    /// Set the current debugging stream.
    void set_debug_stream (std::ostream &);

    /// Type for debugging levels.
    typedef int debug_level_type;
    /// The current debugging level.
    debug_level_type debug_level () const;
    /// Set the current debugging level.
    void set_debug_level (debug_level_type l);

  private:
    /// Report a syntax error.
    /// \param loc    where the syntax error is found.
    /// \param msg    a description of the syntax error.
    virtual void error (const location_type& loc, const std::string& msg);

    /// Generate an error message.
    /// \param state   the state where the error occurred.
    /// \param tok     the look-ahead token.
    virtual std::string yysyntax_error_ (int yystate, int tok);

#if YYDEBUG
    /// \brief Report a symbol value on the debug stream.
    /// \param yytype       The token type.
    /// \param yyvaluep     Its semantic value.
    /// \param yylocationp  Its location.
    virtual void yy_symbol_value_print_ (int yytype,
					 const semantic_type* yyvaluep,
					 const location_type* yylocationp);
    /// \brief Report a symbol on the debug stream.
    /// \param yytype       The token type.
    /// \param yyvaluep     Its semantic value.
    /// \param yylocationp  Its location.
    virtual void yy_symbol_print_ (int yytype,
				   const semantic_type* yyvaluep,
				   const location_type* yylocationp);
#endif /* ! YYDEBUG */


    /// State numbers.
    typedef int state_type;
    /// State stack type.
    typedef stack<state_type>    state_stack_type;
    /// Semantic value stack type.
    typedef stack<semantic_type> semantic_stack_type;
    /// location stack type.
    typedef stack<location_type> location_stack_type;

    /// The state stack.
    state_stack_type yystate_stack_;
    /// The semantic value stack.
    semantic_stack_type yysemantic_stack_;
    /// The location stack.
    location_stack_type yylocation_stack_;

    /// Internal symbol numbers.
    typedef unsigned char token_number_type;
    /* Tables.  */
    /// For a state, the index in \a yytable_ of its portion.
    static const short int yypact_[];
    static const short int yypact_ninf_;

    /// For a state, default rule to reduce.
    /// Unless\a  yytable_ specifies something else to do.
    /// Zero means the default is an error.
    static const unsigned char yydefact_[];

    static const short int yypgoto_[];
    static const short int yydefgoto_[];

    /// What to do in a state.
    /// \a yytable_[yypact_[s]]: what to do in state \a s.
    /// - if positive, shift that token.
    /// - if negative, reduce the rule which number is the opposite.
    /// - if zero, do what YYDEFACT says.
    static const short int yytable_[];
    static const signed char yytable_ninf_;

    static const short int yycheck_[];

    /// For a state, its accessing symbol.
    static const unsigned char yystos_[];

    /// For a rule, its LHS.
    static const unsigned char yyr1_[];
    /// For a rule, its RHS length.
    static const unsigned char yyr2_[];

#if YYDEBUG || YYERROR_VERBOSE || YYTOKEN_TABLE
    /// For a symbol, its name in clear.
    static const char* const yytname_[];
#endif

#if YYERROR_VERBOSE
    /// Convert the symbol name \a n to a form suitable for a diagnostic.
    virtual std::string yytnamerr_ (const char *n);
#endif

#if YYDEBUG
    /// A type to store symbol numbers and -1.
    typedef short int rhs_number_type;
    /// A `-1'-separated list of the rules' RHS.
    static const rhs_number_type yyrhs_[];
    /// For each rule, the index of the first RHS symbol in \a yyrhs_.
    static const unsigned short int yyprhs_[];
    /// For each rule, its source line number.
    static const unsigned short int yyrline_[];
    /// For each scanner token number, its symbol number.
    static const unsigned short int yytoken_number_[];
    /// Report on the debug stream that the rule \a r is going to be reduced.
    virtual void yy_reduce_print_ (int r);
    /// Print the state stack on the debug stream.
    virtual void yystack_print_ ();
#endif

    /// Convert a scanner token number \a t to a symbol number.
    token_number_type yytranslate_ (int t);

    /// \brief Reclaim the memory associated to a symbol.
    /// \param yymsg        Why this token is reclaimed.
    /// \param yytype       The symbol type.
    /// \param yyvaluep     Its semantic value.
    /// \param yylocationp  Its location.
    inline void yydestruct_ (const char* yymsg,
			     int yytype,
			     semantic_type* yyvaluep,
			     location_type* yylocationp);

    /// Pop \a n symbols the three stacks.
    inline void yypop_ (unsigned int n = 1);

    /* Constants.  */
    static const int yyeof_;
    /* LAST_ -- Last index in TABLE_.  */
    static const int yylast_;
    static const int yynnts_;
    static const int yyempty_;
    static const int yyfinal_;
    static const int yyterror_;
    static const int yyerrcode_;
    static const int yyntokens_;
    static const unsigned int yyuser_token_number_max_;
    static const token_number_type yyundef_token_;

    /* Debugging.  */
    int yydebug_;
    std::ostream* yycdebug_;


    /* User arguments.  */
    class Driver& driver;
  };
}


#endif /* ! defined PARSER_HEADER_H */
