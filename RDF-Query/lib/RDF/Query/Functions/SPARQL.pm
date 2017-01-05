=head1 NAME

RDF::Query::Functions::SPARQL - SPARQL built-in functions

=head1 VERSION

This document describes RDF::Query::Functions::SPARQL version 2.918.

=head1 DESCRIPTION

Defines the following functions:

=over 4

=item * sparql:abs

=item * sparql:bnode

=item * sparql:bound

=item * sparql:ceil

=item * sparql:coalesce

=item * sparql:concat

=item * sparql:contains

=item * sparql:datatype

=item * sparql:ebv

=item * sparql:strends

=item * sparql:floor

=item * sparql:encode_for_uri

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

=item * sparql:lcase

=item * sparql:logical-and

=item * sparql:logical-or

=item * sparql:notin

=item * sparql:rand

=item * sparql:regex

=item * sparql:round

=item * sparql:sameterm

=item * sparql:strstarts

=item * sparql:str

=item * sparql:strdt

=item * sparql:strlang

=item * sparql:strlen

=item * sparql:substr

=item * sparql:ucase

=item * sparql:uri

=item * sparql:uuid

=item * sparql:struuid

=cut

package RDF::Query::Functions::SPARQL;

use strict;
use warnings;
use Log::Log4perl;
our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.sparql");
	$VERSION	= '2.918';
}

use POSIX;
use Encode;
use URI::Escape;
use Carp qw(carp croak confess);
use Data::Dumper;
use I18N::LangTags;
use List::Util qw(sum);
use Scalar::Util qw(blessed reftype refaddr looks_like_number);
use DateTime::Format::W3CDTF;
use RDF::Trine::Namespace qw(rdf xsd);
use Digest::MD5 qw(md5_hex);
use Digest::SHA  qw(sha1_hex sha224_hex sha256_hex sha384_hex sha512_hex);
use Data::UUID;

use RDF::Query::Error qw(:try);
use RDF::Query::Node qw(iri literal);

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
				throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:double" );
			} elsif ($node->is_blank) {
				throw RDF::Query::Error::TypeError -text => "cannot cast bnode to xsd:double";
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
			unless ($value =~ m<-?\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d([.]\d+)?(Z|[-+]\d\d:\d\d)?>) {
				throw RDF::Query::Error::TypeError -text => "Not a valid lexical form for xsd:dateTime: '$value'";
			}
			my $dt		= eval { $f->parse_datetime( $value ) };
			if ($dt) {
				my $value	= DateTime::Format::W3CDTF->new->format_datetime( $dt );
				return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
			} else {
				throw RDF::Query::Error::TypeError -text => "Failed to parse lexical form as xsd:dateTime: '$value'";
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
			
			unless ($str->is_simple_literal) {
				throw RDF::Query::Error::TypeError -text => "STRDT() not called with a simple literal";
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
				throw RDF::Query::Error::TypeError -text => "STRLANG() must be called with two plain literals";
			}
			
			unless ($str->is_simple_literal) {
				throw RDF::Query::Error::TypeError -text => "STRLANG() not called with a simple literal";
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
			
			my $base	= $query->{parsed}{base};
			
			if ($node->is_literal) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Resource->new( $value, $base );
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
					return $rdf->langString;
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
			my $graph	= shift;
			my ($plan)	= RDF::Query::Plan->generate_plans( $ggp, $context, active_graph => $graph );
			
			Carp::confess "No execution contexted passed to sparql:exists" unless (blessed($context));
			
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
	
	# sparql:abs
	RDF::Query::Functions->install_function(
		"sparql:abs",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
				my $value	= $node->numeric_value;
				return RDF::Query::Node::Literal->new( abs($value), undef, $node->literal_datatype );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:abs called without a numeric literal";
			}
		}
	);
	

	# sparql:ceil
	RDF::Query::Functions->install_function(
		"sparql:ceil",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
				my $value	= $node->numeric_value;
				return RDF::Query::Node::Literal->new( ceil($value), undef, $node->literal_datatype );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:ceil called without a numeric literal";
			}
		}
	);
	

	# sparql:floor
	RDF::Query::Functions->install_function(
		"sparql:floor",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
				my $value	= $node->numeric_value;
				return RDF::Query::Node::Literal->new( floor($value), undef, $node->literal_datatype );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:floor called without a numeric literal";
			}
		}
	);
	

	# sparql:round
	RDF::Query::Functions->install_function(
		"sparql:round",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
				my $value	= $node->numeric_value;
				my $mult	= 1;
				if ($value < 0) {
					$mult	= -1;
					$value	= -$value;
				}
				my $round	= $mult * POSIX::floor($value + 0.50000000000008);
				return RDF::Query::Node::Literal->new( $round, undef, $node->literal_datatype );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:round called without a numeric literal";
			}
		}
	);
	

	# sparql:concat
	RDF::Query::Functions->install_function(
		"sparql:concat",
		sub {
			my $query	= shift;
			my @nodes	= @_;
			
			my $lang;
			my $all_lang	= 1;
			my $all_str		= 1;
			foreach my $n (@nodes) {
				unless ($n->isa('RDF::Query::Node::Literal')) {
					throw RDF::Query::Error::TypeError -text => "sparql:concat called with a non-literal argument";
				}
				if ($n->has_datatype) {
					$all_lang	= 0;
					my $dt	= $n->literal_datatype;
					if ($dt ne 'http://www.w3.org/2001/XMLSchema#string') {
						throw RDF::Query::Error::TypeError -text => "sparql:concat called with a datatyped-literal other than xsd:string";
					}
				} elsif ($n->has_language) {
					$all_str	= 0;
					if (defined($lang) and $lang ne $n->literal_value_language) {
						$all_lang	= 0;
					} else {
						$lang	= $n->literal_value_language;
					}
				} else {
					$all_lang	= 0;
					$all_str	= 0;
				}
			}
			
			my @strtype;
			if ($all_lang) {
				$strtype[0]	= $lang;
			} elsif ($all_str) {
				$strtype[1]	= 'http://www.w3.org/2001/XMLSchema#string'
			}
			my $value	= join('', map { $_->literal_value } @nodes);
			return RDF::Query::Node::Literal->new($value, @strtype);
		}
	);
	

	# sparql:substr
	RDF::Query::Functions->install_function(
		"sparql:substr",
		sub {
			my $query	= shift;
			my $node	= shift;
			my @args	= @_;
			unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
				throw RDF::Query::Error::TypeError -text => "sparql:substr called without a literal arg1 term";
			}
			my $value	= $node->literal_value;
			my @nums;
			foreach my $i (0 .. $#args) {
				my $argnum	= $i + 2;
				my $arg		= $args[ $i ];
				unless (blessed($arg) and $arg->isa('RDF::Query::Node::Literal') and $arg->is_numeric_type) {
					throw RDF::Query::Error::TypeError -text => "sparql:substr called without a numeric literal arg${argnum} term";
				}
				push(@nums, $arg->numeric_value);
			}
			
			$nums[0]--;
			my $substring	= (scalar(@nums) > 1) ? substr($value, $nums[0], $nums[1]) : substr($value, $nums[0]);
			return RDF::Query::Node::Literal->new($substring, $node->type_list);
		}
	);
	

	# sparql:strlen
	RDF::Query::Functions->install_function(
		"sparql:strlen",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Literal->new( length($value), undef, $xsd->integer );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:strlen called without a literal term";
			}
		}
	);
	

	# sparql:ucase
	RDF::Query::Functions->install_function(
		"sparql:ucase",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Literal->new( uc($value), $node->type_list );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:ucase called without a literal term";
			}
		}
	);
	

	# sparql:lcase
	RDF::Query::Functions->install_function(
		"sparql:lcase",
		sub {
			my $query	= shift;
			my $node	= shift;
			if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
				my $value	= $node->literal_value;
				return RDF::Query::Node::Literal->new( lc($value), $node->type_list );
			} else {
				throw RDF::Query::Error::TypeError -text => "sparql:lcase called without a literal term";
			}
		}
	);
	
	RDF::Query::Functions->install_function("sparql:encode_for_uri", \&_encode_for_uri);
	RDF::Query::Functions->install_function("sparql:contains", \&_contains);
	RDF::Query::Functions->install_function("sparql:strstarts", \&_strstarts);
	RDF::Query::Functions->install_function("sparql:strends", \&_strends);
	RDF::Query::Functions->install_function("sparql:rand", \&_rand);
	
	RDF::Query::Functions->install_function("sparql:md5", \&_md5);
	RDF::Query::Functions->install_function("sparql:sha1", \&_sha1);
	RDF::Query::Functions->install_function("sparql:sha224", \&_sha224);
	RDF::Query::Functions->install_function("sparql:sha256", \&_sha256);
	RDF::Query::Functions->install_function("sparql:sha384", \&_sha384);
	RDF::Query::Functions->install_function("sparql:sha512", \&_sha512);
	
	RDF::Query::Functions->install_function("sparql:year", \&_year);
	RDF::Query::Functions->install_function("sparql:month", \&_month);
	RDF::Query::Functions->install_function("sparql:day", \&_day);
	RDF::Query::Functions->install_function("sparql:hours", \&_hours);
	RDF::Query::Functions->install_function("sparql:minutes", \&_minutes);
	RDF::Query::Functions->install_function("sparql:seconds", \&_seconds);
	RDF::Query::Functions->install_function("sparql:timezone", \&_timezone);
	RDF::Query::Functions->install_function("sparql:tz", \&_tz);
	RDF::Query::Functions->install_function("sparql:now", \&_now);

	RDF::Query::Functions->install_function("sparql:strbefore", \&_strbefore);
	RDF::Query::Functions->install_function("sparql:strafter", \&_strafter);
	RDF::Query::Functions->install_function("sparql:replace", \&_replace);

	RDF::Query::Functions->install_function("sparql:uuid", \&_uuid);
	RDF::Query::Functions->install_function("sparql:struuid", \&_struuid);
}

=item * sparql:encode_for_uri

=cut

sub _encode_for_uri {
	my $query	= shift;
	my $node	= shift;
	if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		my $value	= $node->literal_value;
		return RDF::Query::Node::Literal->new( uri_escape_utf8($value) );
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:encode_for_uri called without a literal term";
	}
}

=item * sparql:contains

=cut

sub _contains {
	my $query	= shift;
	my $node	= shift;
	my $pat		= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:contains called without a literal arg1 term";
	}
	unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:contains called without a literal arg2 term";
	}
	
	# TODO: what should be returned if one or both arguments are typed as xsd:string?
	if ($node->has_language and $pat->has_language) {
		if ($node->literal_value_language ne $pat->literal_value_language) {
			throw RDF::Query::Error::TypeError -text => "sparql:contains called with literals of different languages";
		}
	}
	
	my $lit		= $node->literal_value;
	my $plit	= $pat->literal_value;
	my $pos		= index($lit, $plit);
	if ($pos >= 0) {
		return RDF::Query::Node::Literal->new('true', undef, $xsd->boolean);
	} else {
		return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
	}
}

=item * sparql:strstarts

=cut

sub _strstarts {
	my $query	= shift;
	my $node	= shift;
	my $pat		= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strstarts called without a literal arg1 term";
	}
	unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strstarts called without a literal arg2 term";
	}

	# TODO: what should be returned if one or both arguments are typed as xsd:string?
	if ($node->has_language and $pat->has_language) {
		# TODO: if the language tags are different, does this error, or just return false?
		if ($node->literal_value_language ne $pat->literal_value_language) {
			return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
		}
	}
	
	if (index($node->literal_value, $pat->literal_value) == 0) {
		return RDF::Query::Node::Literal->new('true', undef, $xsd->boolean);
	} else {
		return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
	}
}

=item * sparql:strends

=cut

sub _strends {
	my $query	= shift;
	my $node	= shift;
	my $pat		= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strends called without a literal arg1 term";
	}
	unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strends called without a literal arg2 term";
	}
	
	# TODO: what should be returned if one or both arguments are typed as xsd:string?
	if ($node->has_language and $pat->has_language) {
		# TODO: if the language tags are different, does this error, or just return false?
		if ($node->literal_value_language ne $pat->literal_value_language) {
			return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
		}
	}
	
	my $lit		= $node->literal_value;
	my $plit	= $pat->literal_value;
	my $pos	= length($lit) - length($plit);
	if (rindex($lit, $plit) == $pos) {
		return RDF::Query::Node::Literal->new('true', undef, $xsd->boolean);
	} else {
		return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
	}
}

=item * sparql:rand

=cut

sub _rand {
	my $query	= shift;
	my $r		= rand();
	my $value	= RDF::Trine::Node::Literal->canonicalize_literal_value( $r, $xsd->double->as_string );
	return RDF::Query::Node::Literal->new($value, undef, $xsd->double);
}

=item * sparql:md5

=cut

sub _md5 {
	my $query	= shift;
	my $node	= shift;
	return literal( md5_hex(encode_utf8($node->literal_value)) );
}

=item * sparql:sha1

=cut

sub _sha1 {
	my $query	= shift;
	my $node	= shift;
	return literal( sha1_hex(encode_utf8($node->literal_value)) );
}

=item * sparql:sha224

=cut

sub _sha224 {
	my $query	= shift;
	my $node	= shift;
	return literal( sha224_hex(encode_utf8($node->literal_value)) );
}

=item * sparql:sha256

=cut

sub _sha256 {
	my $query	= shift;
	my $node	= shift;
	return literal( sha256_hex(encode_utf8($node->literal_value)) );
}

=item * sparql:sha384

=cut

sub _sha384 {
	my $query	= shift;
	my $node	= shift;
	return literal( sha384_hex(encode_utf8($node->literal_value)) );
}

=item * sparql:sha512

=cut

sub _sha512 {
	my $query	= shift;
	my $node	= shift;
	return literal( sha512_hex(encode_utf8($node->literal_value)) );
}

=item * sparql:year

=cut

sub _year {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:year called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		return RDF::Query::Node::Literal->new($dt->year, undef, $xsd->integer);
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:year called without a valid dateTime";
	}
}

=item * sparql:month

=cut

sub _month {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:month called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		return RDF::Query::Node::Literal->new($dt->month, undef, $xsd->integer);
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:month called without a valid dateTime";
	}
}

=item * sparql:day

=cut

sub _day {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:day called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		return RDF::Query::Node::Literal->new($dt->day, undef, $xsd->integer);
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:day called without a valid dateTime";
	}
}

=item * sparql:hours

=cut

sub _hours {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:hours called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		return RDF::Query::Node::Literal->new($dt->hour, undef, $xsd->integer);
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:hours called without a valid dateTime";
	}
}

=item * sparql:minutes

=cut

sub _minutes {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:minutes called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		return RDF::Query::Node::Literal->new($dt->minute, undef, $xsd->integer);
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:minutes called without a valid dateTime";
	}
}

=item * sparql:seconds

=cut

sub _seconds {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:seconds called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		return RDF::Query::Node::Literal->new($dt->second, undef, $xsd->decimal);
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:seconds called without a valid dateTime";
	}
}

=item * sparql:timezone

=cut

sub _timezone {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:timezone called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		my $tz		= $dt->time_zone;
		if ($tz->is_floating) {
			throw RDF::Query::Error::TypeError -text => "sparql:timezone called with a dateTime without a timezone";
		}
		if ($tz) {
			my $offset	= $tz->offset_for_datetime( $dt );
			my $minus	= '';
			if ($offset < 0) {
				$minus	= '-';
				$offset	= -$offset;
			}

			my $duration	= "${minus}PT";
			if ($offset >= 60*60) {
				my $h	= int($offset / (60*60));
				$duration	.= "${h}H" if ($h > 0);
				$offset	= $offset % (60*60);
			}
			if ($offset >= 60) {
				my $m	= int($offset / 60);
				$duration	.= "${m}M" if ($m > 0);
				$offset	= $offset % 60;
			}
			my $s	= int($offset);
			$duration	.= "${s}S" if ($s > 0 or $duration eq 'PT');
			
			return RDF::Query::Node::Literal->new($duration, undef, $xsd->dayTimeDuration);
		}
	}
	throw RDF::Query::Error::TypeError -text => "sparql:timezone called without a valid dateTime";
}

=item * sparql:tz

=cut

sub _tz {
	my $query	= shift;
	my $node	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:tz called without a literal term";
	}
	my $dt		= $node->datetime;
	if ($dt) {
		my $tz		= $dt->time_zone;
		if ($tz->is_floating) {
			return RDF::Query::Node::Literal->new('');
		}
		if ($tz->is_utc) {
			return RDF::Query::Node::Literal->new('Z');
		}
		if ($tz) {
			my $offset	= $tz->offset_for_datetime( $dt );
			my $hours	= 0;
			my $minutes	= 0;
			my $minus	= '+';
			if ($offset < 0) {
				$minus	= '-';
				$offset	= -$offset;
			}

			if ($offset >= 60*60) {
				$hours	= int($offset / (60*60));
				$offset	= $offset % (60*60);
			}
			if ($offset >= 60) {
				$minutes	= int($offset / 60);
				$offset	= $offset % 60;
			}
			my $seconds	= int($offset);
			
			my $tz	= sprintf('%s%02d:%02d', $minus, $hours, $minutes);
			return RDF::Query::Node::Literal->new($tz);
		} else {
			return RDF::Query::Node::Literal->new('');
		}
	}
	throw RDF::Query::Error::TypeError -text => "sparql:tz called without a valid dateTime";
}

=item * sparql:now

=cut

sub _now {
	my $query	= shift;
	my $dt		= DateTime->now;
	my $value	= DateTime::Format::W3CDTF->new->format_datetime( $dt );
	return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
}

=item * sparql:strbefore

=cut

sub _strbefore {
	my $query	= shift;
	my $node	= shift;
	my $substr	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strbefore called without a literal arg1 term";
	}
	unless (blessed($substr) and $substr->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strbefore called without a literal arg2 term";
	}
	if ($node->has_datatype and $node->literal_datatype ne 'http://www.w3.org/2001/XMLSchema#string') {
		throw RDF::Query::Error::TypeError -text => "sparql:strbefore called with a datatyped (non-xsd:string) literal";
	}
	
	my $lhs_simple	= not($node->has_language or $node->has_datatype);
	my $lhs_xsd		= ($node->has_datatype and $node->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#string');
	my $rhs_simple	= not($substr->has_language or $substr->has_datatype);
	my $rhs_xsd		= ($substr->has_datatype and $substr->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#string');
	if (($lhs_simple or $lhs_xsd) and ($rhs_simple or $rhs_xsd)) {
		# ok
	} elsif ($node->has_language and $substr->has_language and $node->literal_value_language eq $substr->literal_value_language) {
		# ok
	} elsif ($node->has_language and ($rhs_simple or $rhs_xsd)) {
		# ok
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:strbefore called with literals that are not argument compatible";
	}
	
	my $value	= $node->literal_value;
	my $match	= $substr->literal_value;
	my $i		= index($value, $match, 0);
	if ($i < 0) {
		return RDF::Query::Node::Literal->new('');
	} else {
		return RDF::Query::Node::Literal->new(substr($value, 0, $i), $node->type_list);
	}
}

=item * sparql:strafter

=cut

sub _strafter {
	my $query	= shift;
	my $node	= shift;
	my $substr	= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strafter called without a literal arg1 term";
	}
	unless (blessed($substr) and $substr->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:strafter called without a literal arg2 term";
	}
	if ($node->has_datatype and $node->literal_datatype ne 'http://www.w3.org/2001/XMLSchema#string') {
		throw RDF::Query::Error::TypeError -text => "sparql:strafter called with a datatyped (non-xsd:string) literal";
	}
	
	my $lhs_simple	= not($node->has_language or $node->has_datatype);
	my $lhs_xsd		= ($node->has_datatype and $node->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#string');
	my $rhs_simple	= not($substr->has_language or $substr->has_datatype);
	my $rhs_xsd		= ($substr->has_datatype and $substr->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#string');
	if (($lhs_simple or $lhs_xsd) and ($rhs_simple or $rhs_xsd)) {
		# ok
	} elsif ($node->has_language and $substr->has_language and $node->literal_value_language eq $substr->literal_value_language) {
		# ok
	} elsif ($node->has_language and ($rhs_simple or $rhs_xsd)) {
		# ok
	} else {
		throw RDF::Query::Error::TypeError -text => "sparql:strafter called with literals that are not argument compatible";
	}
	
	my $value	= $node->literal_value;
	my $match	= $substr->literal_value;
	my $i		= index($value, $match, 0);
	if ($i < 0) {
		return RDF::Query::Node::Literal->new('');
	} else {
		return RDF::Query::Node::Literal->new(substr($value, $i+length($match)), $node->type_list);
	}
}

=item * sparql:replace

=cut

sub _replace {
	my $query	= shift;
	my $node	= shift;
	my $pat		= shift;
	my $rep		= shift;
	unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:replace called without a literal arg1 term";
	}
	unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:replace called without a literal arg2 term";
	}
	unless (blessed($rep) and $rep->isa('RDF::Query::Node::Literal')) {
		throw RDF::Query::Error::TypeError -text => "sparql:replace called without a literal arg3 term";
	}
	if ($node->has_datatype and $node->literal_datatype ne 'http://www.w3.org/2001/XMLSchema#string') {
		throw RDF::Query::Error::TypeError -text => "sparql:replace called with a datatyped (non-xsd:string) literal";
	}
	my $value	= $node->literal_value;
	my $pattern	= $pat->literal_value;
	my $replace	= $rep->literal_value;
	if (index($pattern, '(?{') != -1 or index($pattern, '(??{') != -1) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => 'REPLACE() called with unsafe ?{} match pattern' );
	}
	if (index($replace, '(?{') != -1 or index($replace, '(??{') != -1) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => 'REPLACE() called with unsafe ?{} replace pattern' );
	}
	
	$replace	=~ s/\\/\\\\/g;
 	$replace	=~ s/\$(\d+)/\$$1/g;
 	$replace	=~ s/"/\\"/g;
 	$replace	= qq["$replace"];
 	no warnings 'uninitialized';
	$value	=~ s/$pattern/"$replace"/eeg;
# 	warn "==> " . Dumper($value);
	return RDF::Query::Node::Literal->new($value, $node->type_list);
}

sub _uuid {
	my $query	= shift;
	my $u		= Data::UUID->new();
	return iri('urn:uuid:' . $u->to_string( $u->create() ));
}

sub _struuid {
	my $query	= shift;
	my $u		= Data::UUID->new();
	return literal($u->to_string( $u->create() ));
}


1;

__END__

=item * http://www.w3.org/2001/XMLSchema#boolean

=item * http://www.w3.org/2001/XMLSchema#dateTime

=item * http://www.w3.org/2001/XMLSchema#decimal

=item * http://www.w3.org/2001/XMLSchema#double

=item * http://www.w3.org/2001/XMLSchema#float

=item * http://www.w3.org/2001/XMLSchema#integer

=item * http://www.w3.org/2001/XMLSchema#string

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
