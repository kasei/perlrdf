=head1 NAME

RDF::Query::Functions::SPARQL - SPARQL built-in functions

=head1 VERSION

This document describes RDF::Query::Functions::SPARQL version 2.903.

=head1 DESCRIPTION

Defines the following functions:

=over

=item * sparql:bnode

=item * sparql:bound

=item * sparql:coalesce

=item * sparql:datatype

=item * sparql:ebv

=item * sparql:exists

=item * sparql:in

=item * sparql:iri

=item * sparql:isblank

=item * sparql:isiri

=item * sparql:isliteral

=item * sparql:isuri

=item * sparql:isNumeric

=item * sparql:lang

=item * sparql:langmatches

=item * sparql:logical-and

=item * sparql:logical-or

=item * sparql:notin

=item * sparql:regex

=item * sparql:sameterm

=item * sparql:str

=item * sparql:strdt

=item * sparql:strlang

=item * sparql:uri

=item * http://www.w3.org/2001/XMLSchema#boolean

=item * http://www.w3.org/2001/XMLSchema#dateTime

=item * http://www.w3.org/2001/XMLSchema#decimal

=item * http://www.w3.org/2001/XMLSchema#double

=item * http://www.w3.org/2001/XMLSchema#float

=item * http://www.w3.org/2001/XMLSchema#integer

=item * http://www.w3.org/2001/XMLSchema#string

=back

=cut

package RDF::Query::Functions::SPARQL;

use strict;
use warnings;
use Log::Log4perl;
our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.sparql");
	$VERSION	= '2.903';
}

use Carp qw(carp croak confess);
use Data::Dumper;
use I18N::LangTags;
use RDF::Query::Error qw(:try);
use Scalar::Util qw(blessed reftype refaddr looks_like_number);

=begin private

=item C<< install >>

Documented in L<RDF::Query::Functions>.

=end private

=cut

sub install {
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#integer",
		sub {
			my $query	= shift;
			my $node	= shift;
			my $value;
			if (blessed($node) and $node->isa('RDF::Trine::Node::Literal')) {
				my $type	= $node->literal_datatype || '';
				$value		= $node->literal_value;
				if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
					$value	= ($value eq 'true') ? '1' : '0';
				} elsif ($node->is_numeric_type) {
					if ($type eq 'http://www.w3.org/2001/XMLSchema#double') {
						throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot cast to xsd:integer as precision would be lost" );
					} elsif (int($value) != $value) {
						throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot cast to xsd:integer as precision would be lost" );
					} else {
						$value	= $node->numeric_value;
					}
				} elsif (looks_like_number($value)) {
					if ($value =~ /[eE]/) {	# double
						throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot to xsd:integer as precision would be lost" );
					} elsif (int($value) != $value) {
						throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot to xsd:integer as precision would be lost" );
					}
				} else {
					throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:integer" );
				}
				return RDF::Query::Node::Literal->new( "$value", undef, 'http://www.w3.org/2001/XMLSchema#integer' );
			} else {
				throw RDF::Query::Error::TypeError ( -text => "cannot cast node to xsd:integer" );
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#decimal",
		sub {
			my $query	= shift;
			my $node	= shift;
			my $value;
			if ($node->is_literal) {
				my $type	= $node->literal_datatype || '';
				$value		= $node->literal_value;
				if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
					$value	= ($value eq 'true') ? '1' : '0';
				} elsif ($node->is_numeric_type) {
					if ($type eq 'http://www.w3.org/2001/XMLSchema#double') {
						throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot to xsd:decimal as precision would be lost" );
					} else {
						$value	= $node->numeric_value;
					}
				} elsif (looks_like_number($value)) {
					if ($value =~ /[eE]/) {	# double
						throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot to xsd:decimal as precision would be lost" );
					}
				} else {
					throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:decimal" );
				}
				return RDF::Query::Node::Literal->new( "$value", undef, 'http://www.w3.org/2001/XMLSchema#decimal' );
			} else {
				throw RDF::Query::Error::TypeError ( -text => "cannot cast node to xsd:integer" );
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#float",
		sub {
			my $query	= shift;
			my $node	= shift;
			my $value;
			if ($node->is_literal) {
				$value	= $node->literal_value;
				my $type	= $node->literal_datatype || '';
				if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
					$value	= ($value eq 'true') ? '1.0' : '0.0';
				} elsif ($node->is_numeric_type) {
					# noop
				} elsif (not $node->has_datatype) {
					if (looks_like_number($value)) {
						$value	= +$value;
					} else {
						throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:float" );
					}
				} elsif (not $node->is_numeric_type) {
					throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:float" );
				}
			} elsif ($node->is_resource) {
				throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:integer" );
			}
			
			my $num	= sprintf("%e", $value);
			return RDF::Query::Node::Literal->new( $num, undef, 'http://www.w3.org/2001/XMLSchema#float' );
		}
	);
	
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#double",
		sub {
			my $query	= shift;
			my $node	= shift;
			my $value;
			if ($node->is_literal) {
				$value	= $node->literal_value;
				my $type	= $node->literal_datatype || '';
				if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
					$value	= ($value eq 'true') ? '1.0' : '0.0';
				} elsif ($node->is_numeric_type) {
					# noop
				} elsif (not $node->has_datatype) {
					if (looks_like_number($value)) {
						$value	= +$value;
					} else {
						throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:double" );
					}
				} elsif (not $node->is_numeric_type) {
					throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:double" );
				}
			} elsif ($node->is_resource) {
				throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:integer" );
			}
			
			my $num	= sprintf("%e", $value);
			return RDF::Query::Node::Literal->new( $num, undef, 'http://www.w3.org/2001/XMLSchema#double' );
		}
	);
	
	### Effective Boolean Value
	RDF::Query::Functions->install_function(
		"sparql:ebv",
		sub {
			my $query	= shift;
			my $node	= shift;
			
			if ($node->is_literal) {
				if ($node->is_numeric_type) {
					my $value	= $node->numeric_value;
					return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if ($value);
					return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if (not $value);
				} elsif ($node->has_datatype) {
					my $type	= $node->literal_datatype;
					my $value	= $node->literal_value;
					if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
						return ($value eq 'true')
							? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
							: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					} else {
						throw RDF::Query::Error::TypeError -text => "Unusable type in EBV: " . Dumper($node);
					}
				} else {
					my $value	= $node->literal_value;
					return (length($value))
							? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
							: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				}
				throw RDF::Query::Error::FilterEvaluationError ( -text => "'$node' cannot be cast to a boolean type (true or false)" );
			} elsif ($node->is_resource) {
				throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:boolean" );
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#boolean",
		sub {
			my $query	= shift;
			my $node	= shift;
			
			if ($node->is_literal) {
				if ($node->is_numeric_type) {
					my $value	= $node->numeric_value;
					if ($value) {
						return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					} else {
						return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					}
				} elsif ($node->has_datatype) {
					my $type	= $node->literal_datatype;
					my $value	= $node->literal_value;
					if ($value eq 'true') {
						return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					} elsif ($value eq 'false') {
						return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					} else {
						throw RDF::Query::Error::TypeError -text => "Unusable type in boolean cast: " . Dumper($node);
					}
				} else {
					my $value	= $node->literal_value;
					if ($value eq 'true') {
						return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					} elsif ($value eq 'false') {
						return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					} else {
						throw RDF::Query::Error::TypeError -text => "Cannot cast to xsd:boolean: " . Dumper($node);
					}
				}
			} else {
				throw RDF::Query::Error::TypeError -text => "Cannot cast to xsd:boolean: " . Dumper($node);
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#string",
		sub {
			my $query	= shift;
			my $node	= shift;
			if ($node->is_literal) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Literal->new($value, undef, 'http://www.w3.org/2001/XMLSchema#string');
			} elsif ($node->is_resource) {
				my $value	= $node->uri_value;
				return RDF::Query::Node::Literal->new($value, undef, 'http://www.w3.org/2001/XMLSchema#string');
			} else {
				throw RDF::Query::Error::TypeError ( -text => "cannot cast node to xsd:string: " . $node );
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"http://www.w3.org/2001/XMLSchema#dateTime",
		sub {
			my $query	= shift;
			my $node	= shift;
			my $f		= ref($query) ? $query->dateparser : DateTime::Format::W3CDTF->new;
			my $value	= $node->literal_value;
			my $dt		= eval { $f->parse_datetime( $value ) };
			if ($dt) {
				my $value	= $f->format_datetime( $dt );
				return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
			} else {
				throw RDF::Query::Error::TypeError;
			}
		}
	);
	
	
	RDF::Query::Functions->install_function(
		"sparql:str",
		sub {
			my $query	= shift;
			my $node	= shift;
			
			unless (blessed($node)) {
				throw RDF::Query::Error::TypeError -text => "STR() must be called with either a literal or resource";
			}
			
			if ($node->is_literal) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Literal->new( $value );
			} elsif ($node->is_resource) {
				my $value	= $node->uri_value;
				return RDF::Query::Node::Literal->new( $value );
			} else {
				throw RDF::Query::Error::TypeError -text => "STR() must be called with either a literal or resource";
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		["http://www.w3.org/ns/sparql#strdt", "sparql:strdt"],
		sub {
			my $query	= shift;
			my $str		= shift;
			my $dt		= shift;
			
			unless (blessed($str) and $str->isa('RDF::Query::Node::Literal') and blessed($dt) and $dt->isa('RDF::Query::Node::Resource')) {
				throw RDF::Query::Error::TypeError -text => "STRDT() must be called with a plain literal and a datatype IRI";
			}
			
			my $value	= $str->literal_value;
			my $uri		= $dt->uri_value;
			return RDF::Query::Node::Literal->new( $value, undef, $uri );
		}
	);
	
	RDF::Query::Functions->install_function(
		["http://www.w3.org/ns/sparql#strlang", "sparql:strlang"],
		sub {
			my $query	= shift;
			my $str		= shift;
			my $lang	= shift;
			
			unless (blessed($str) and $str->isa('RDF::Query::Node::Literal') and blessed($lang) and $lang->isa('RDF::Query::Node::Literal')) {
				warn Dumper($str,$lang);
				throw RDF::Query::Error::TypeError -text => "STRLANG() must be called with two plain literals";
			}
			
			my $value	= $str->literal_value;
			my $langtag	= $lang->literal_value;
			return RDF::Query::Node::Literal->new( $value, $langtag );
		}
	);
	
	RDF::Query::Functions->install_function(
		["sparql:uri", "sparql:iri"],
		sub {
			my $query	= shift;
			my $node	= shift;
			
			unless (blessed($node)) {
				throw RDF::Query::Error::TypeError -text => "URI/IRI() must be called with either a literal or resource";
			}
			
			if ($node->is_literal) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Resource->new( $value );
			} elsif ($node->is_resource) {
				return $node;
			} else {
				throw RDF::Query::Error::TypeError -text => "URI/IRI() must be called with either a literal or resource";
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:bnode",
		sub {
			my $query	= shift;
			if (@_) {
				my $node	= shift;
				unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
					throw RDF::Query::Error::TypeError -text => "BNODE() must be called with either a literal or resource";
				}
				my $value	= $node->literal_value;
				if (my $bnode = $query->{_query_row_cache}{'sparql:bnode'}{$value}) {
					return $bnode;
				} else {
					my $bnode	= RDF::Query::Node::Blank->new();
					$query->{_query_row_cache}{'sparql:bnode'}{$value}	= $bnode;
					return $bnode;
				}
			} else {
				return RDF::Query::Node::Blank->new();
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:logical-or",
		sub {
			my $query	= shift;
			### Arguments to sparql:logical-* functions are passed lazily via a closure
			### so that TypeErrors in arguments can be handled properly.
			my $args	= shift;
			
			my $l		= Log::Log4perl->get_logger("rdf.query.functions.logicalor");
			$l->trace('executing logical-or');
			my $ebv		= RDF::Query::Node::Resource->new( "sparql:ebv" );
			my $arg;
			my $error;
			
			while (1) {
				my $bool;
				try {
					$l->trace('- getting logical-or operand...');
					$arg 	= $args->();
					if (defined($arg)) {
						$l->trace("- logical-or operand: $arg");
						my $func	= RDF::Query::Expression::Function->new( $ebv, $arg );
						my $value	= $func->evaluate( $query, {} );
						$bool		= ($value->literal_value eq 'true') ? 1 : 0;
					}
				} otherwise {
					my $e	= shift;
					$l->debug("error in lhs of logical-or: " . $e->text . " at " . $e->file . " line " . $e->line);
					$error	||= $e;
				};
				last unless (defined($arg));
				if ($bool) {
					return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				}
			}
			if ($error) {
				$l->debug('logical-or error: ' . $error->text);
				$error->throw;
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
		# sparql:logical-and
	RDF::Query::Functions->install_function(
		"sparql:logical-and",
		sub {
			my $query	= shift;
			### Arguments to sparql:logical-* functions are passed lazily via a closure
			### so that TypeErrors in arguments can be handled properly.
			my $args	= shift;
			
			my $l		= Log::Log4perl->get_logger("rdf.query.functions.logicaland");
			$l->trace('executing logical-and');
			my $ebv		= RDF::Query::Node::Resource->new( "sparql:ebv" );
			my $arg;
			my $error;
			
			while (1) {
				my $bool;
				try {
					$l->trace('- getting logical-and operand...');
					$arg 	= $args->();
					if (defined($arg)) {
						$l->trace("- logical-and operand: $arg");
						my $func	= RDF::Query::Expression::Function->new( $ebv, $arg );
						my $value	= $func->evaluate( $query, {} );
						$bool		= ($value->literal_value eq 'true') ? 1 : 0;
					}
				} otherwise {
					my $e	= shift;
					$l->debug("error in lhs of logical-and: " . $e->text);
					$error	||= $e;
				};
				last unless (defined($arg));
				unless ($bool) {
					return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				}
			}
			if ($error) {
				$l->debug('logical-and error: ' . $error->text);
				$error->throw;
			} else {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:in",
		sub {
			return __IN_FUNC('in', @_)
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:notin",
		sub {
			return __IN_FUNC('notin', @_)
		}
	);
		
	sub __IN_FUNC {
		my $op		= shift;
		my $query	= shift;
		my $args	= shift;
		my $node	= $args->();
		unless (blessed($node)) {
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		}
		
		my $arg;
		my $error;
		while (1) {
			my $bool;
			try {
				$l->trace("- getting $op operand...");
				$arg 	= $args->();
				if (defined($arg)) {
					$l->trace("- $op operand: $arg");
					my $expr	= RDF::Query::Expression::Binary->new('==', $node, $arg);
					my $value	= $expr->evaluate( $query, {} );
					$bool		= ($value->literal_value eq 'true') ? 1 : 0;
				}
			} catch RDF::Query::Error with {
				my $e	= shift;
				$l->debug("error in lhs of logical-and: " . $e->text);
				$error	||= $e;
			} otherwise {};
			last unless (defined($arg));
			if ($bool) {
				if ($op eq 'notin') {
					return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				} else {
					return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				}
			}
		}
		if ($error) {
			$l->debug("$op error: " . $error->text);
			$error->throw;
		} else {
			if ($op eq 'notin') {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	}
	
	# sparql:bound
	RDF::Query::Functions->install_function(
		["http://www.w3.org/ns/sparql#bound", "sparql:bound"],
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node)) {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		["sparql:isuri", "sparql:isiri"],
		sub {
			my $query	= shift;
			my $node	= shift;
			if ($node->isa('RDF::Trine::Node::Resource')) {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
	# sparql:isblank
	RDF::Query::Functions->install_function(
		"sparql:isblank",
		sub {
			my $query	= shift;
			my $node	= shift;
			if ($node->isa('RDF::Trine::Node::Blank')) {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
		# sparql:isliteral
	RDF::Query::Functions->install_function(
		"sparql:isliteral",
		sub {
			my $query	= shift;
			my $node	= shift;
			if ($node->isa('RDF::Trine::Node::Literal')) {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
	
	RDF::Query::Functions->install_function(
		"sparql:lang",
		sub {
			my $query	= shift;
			my $node	= shift;
			if ($node->is_literal) {
				my $lang	= ($node->has_language) ? $node->literal_value_language : '';
				return RDF::Query::Node::Literal->new( $lang );
			} else {
				throw RDF::Query::Error::TypeError ( -text => "cannot call lang() on a non-literal value" );
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:langmatches",
		sub {
			my $query	= shift;
			my $l		= shift;
			my $m		= shift;
			
			my $lang	= $l->literal_value;
			my $match	= $m->literal_value;
			
			my $true	= RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			my $false	= RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			
			if ($match eq '*') {
				# """A language-range of "*" matches any non-empty language-tag string."""
				return ($lang ? $true : $false);
			} else {
				return (I18N::LangTags::is_dialect_of( $lang, $match )) ? $true : $false;
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:sameterm",
		sub {
			my $query	= shift;
			my $nodea	= shift;
			my $nodeb	= shift;
			
			my $bool	= 0;
			if ($nodea->isa('RDF::Trine::Node::Resource')) {
				$bool	= $nodea->equal( $nodeb );
			} elsif ($nodea->isa('RDF::Trine::Node::Blank')) {
				$bool	= $nodea->equal( $nodeb );
			} elsif ($nodea->isa('RDF::Trine::Node::Literal') and $nodeb->isa('RDF::Trine::Node::Literal')) {
				if ($nodea->literal_value ne $nodeb->literal_value) {
					$bool	= 0;
				} elsif (not($nodea->has_language == $nodeb->has_language)) {
					$bool	= 0;
				} elsif (not $nodea->has_datatype == $nodeb->has_datatype) {
					$bool	= 0;
				} elsif ($nodea->has_datatype or $nodeb->has_datatype) {
					if ($nodea->literal_datatype ne $nodeb->literal_datatype) {
						$bool	= 0;
					} else {
						$bool	= 1;
					}
				} elsif ($nodea->has_language or $nodeb->has_language) {
					if ($nodea->literal_value_language ne $nodeb->literal_value_language) {
						$bool	= 0;
					} else {
						$bool	= 1;
					}
				} else {
					$bool	= 1;
				}
			}
	
			return ($bool)
				? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
				: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:datatype",
		sub {
			# """Returns the datatype IRI of typedLit; returns xsd:string if the parameter is a simple literal."""
			my $query	= shift;
			my $node	= shift;
			unless (blessed($node) and $node->isa('RDF::Query::Node')) {
				throw RDF::Query::Error::MethodInvocationError -text => "DATATYPE() called without a valid RDF Term";
			}
			if ($node->is_literal) {
				if ($node->has_language) {
					throw RDF::Query::Error::TypeError ( -text => "cannot call datatype() on a language-tagged literal" );
				} elsif ($node->has_datatype) {
					my $type	= $node->literal_datatype;
					$l->debug("datatype => $type");
					return RDF::Query::Node::Resource->new($type);
				} else {
					$l->debug('datatype => string');
					return RDF::Query::Node::Resource->new('http://www.w3.org/2001/XMLSchema#string');
				}
			} else {
				throw RDF::Query::Error::TypeError ( -text => "cannot call datatype() on a non datatyped node" );
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:regex",
		sub {
			my $query	= shift;
			my $node	= shift;
			my $match	= shift;
			
			unless ($node->is_literal) {
				throw RDF::Query::Error::TypeError ( -text => 'REGEX() called with non-string data' );
			}
			
			my $text	= $node->literal_value;
			my $pattern	= $match->literal_value;
			if (index($pattern, '(?{') != -1 or index($pattern, '(??{') != -1) {
				throw RDF::Query::Error::FilterEvaluationError ( -text => 'REGEX() called with unsafe ?{} pattern' );
			}
			if (@_) {
				my $data	= shift;
				my $flags	= $data->literal_value;
				if ($flags !~ /^[smix]*$/) {
					throw RDF::Query::Error::FilterEvaluationError ( -text => 'REGEX() called with unrecognized flags' );
				}
				$pattern	= qq[(?${flags}:$pattern)];
			}
			
			return ($text =~ /$pattern/)
				? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
				: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		}
	);
		
	RDF::Query::Functions->install_function(
		"sparql:exists",
		sub {
			my $query	= shift;
			my $context	= shift;
			my $bound	= shift;
			my $ggp		= shift;
			my ($plan)	= RDF::Query::Plan->generate_plans( $ggp, $context );
			
			Carp::confess unless (blessed($context));
			
			my $l		= Log::Log4perl->get_logger("rdf.query.functions.exists");
			my $copy		= $context->copy( bound => $bound );
			$plan->execute( $copy );
			if (my $row = $plan->next) {
				$l->trace("got EXISTS row: $row");
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			} else {
				$l->trace("didn't find EXISTS row");
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	);
	
	RDF::Query::Functions->install_function(
		"sparql:coalesce",
		sub {
			my $query	= shift;
			my $args	= shift;
			while (defined(my $node = $args->())) {
				if (blessed($node)) {
					return $node;
				}
			}
		}
	);
	
	# sparql:isNumeric
	RDF::Query::Functions->install_function(
		"sparql:isnumeric",
		sub {
			my $query	= shift;
			my $node	= shift;
			if ($node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type and $node->is_valid_lexical_form) {
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		}
	);
}

1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
