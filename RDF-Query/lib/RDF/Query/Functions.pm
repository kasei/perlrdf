# RDF::Query::Functions
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Functions - Standard Extension Functions

=head1 VERSION

This document describes RDF::Query::Functions version 2.902.

=cut

package RDF::Query::Functions;

use strict;
use warnings;
no warnings 'redefine';

use Scalar::Util qw(blessed reftype refaddr looks_like_number);

use RDF::Query::Node qw(iri);
use RDF::Query::Error qw(:try);

use Log::Log4perl;
use I18N::LangTags;
use Data::Dumper;
use MIME::Base64;
use Digest::SHA1 qw(sha1_hex);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions");
	$VERSION	= '2.902';
}

######################################################################


### XSD CASTING FUNCTIONS

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#integer"}	= sub {
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
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#decimal"}	= sub {
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
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#float"}	= sub {
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
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#double"}	= sub {
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
};

### Effective Boolean Value
$RDF::Query::functions{"sparql:ebv"}	= sub {
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
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#boolean"}	= sub {
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
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#string"}	= sub {
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
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#dateTime"}	= sub {
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
};


$RDF::Query::functions{"sparql:str"}	= sub {
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
};

$RDF::Query::functions{"sparql:strdt"}	= sub {
	my $query	= shift;
	my $str		= shift;
	my $dt		= shift;
	
	unless (blessed($str) and $str->isa('RDF::Query::Node::Literal') and blessed($dt) and $dt->isa('RDF::Query::Node::Resource')) {
		throw RDF::Query::Error::TypeError -text => "STRDT() must be called with a plain literal and a datatype IRI";
	}
	
	my $value	= $str->literal_value;
	my $uri		= $dt->uri_value;
	return RDF::Query::Node::Literal->new( $value, undef, $uri );
};

$RDF::Query::functions{"sparql:strlang"}	= sub {
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
};

$RDF::Query::functions{"sparql:uri"}	=
$RDF::Query::functions{"sparql:iri"}	= sub {
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
};

$RDF::Query::functions{"sparql:bnode"}	= sub {
	my $query	= shift;
	if (@_) {
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "URI/IRI() must be called with either a literal or resource";
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
};

$RDF::Query::functions{"sparql:logical-or"}	= sub {
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
};

# sop:logical-and
$RDF::Query::functions{"sparql:logical-and"}	= sub {
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
};

$RDF::Query::functions{"sparql:in"}		= sub { return __IN_FUNC('in', @_) };
$RDF::Query::functions{"sparql:notin"}	= sub { return __IN_FUNC('notin', @_) };
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

# sop:isBound
$RDF::Query::functions{"sparql:bound"}	= sub {
	my $query	= shift;
	my $node	= shift;
	if (blessed($node)) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

$RDF::Query::functions{"sparql:isuri"}	=
$RDF::Query::functions{"sparql:isiri"}	= sub {
	my $query	= shift;
	my $node	= shift;
	if ($node->isa('RDF::Trine::Node::Resource')) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sop:isBlank
$RDF::Query::functions{"sparql:isblank"}	= sub {
	my $query	= shift;
	my $node	= shift;
	if ($node->isa('RDF::Trine::Node::Blank')) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sop:isLiteral
$RDF::Query::functions{"sparql:isliteral"}	= sub {
	my $query	= shift;
	my $node	= shift;
	if ($node->isa('RDF::Trine::Node::Literal')) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sparql:isNumeric
$RDF::Query::functions{"sparql:isnumeric"}	= sub {
	my $query	= shift;
	my $node	= shift;
	if ($node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type and $node->is_valid_lexical_form) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
	return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
};


$RDF::Query::functions{"sparql:lang"}	= sub {
	my $query	= shift;
	my $node	= shift;
	if ($node->is_literal) {
		my $lang	= ($node->has_language) ? $node->literal_value_language : '';
		return RDF::Query::Node::Literal->new( $lang );
	} else {
		throw RDF::Query::Error::TypeError ( -text => "cannot call lang() on a non-literal value" );
	}
};

$RDF::Query::functions{"sparql:langmatches"}	= sub {
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
};

$RDF::Query::functions{"sparql:sameterm"}	= sub {
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
};

$RDF::Query::functions{"sparql:datatype"}	= sub {
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
};

$RDF::Query::functions{"sparql:regex"}	= sub {
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
};

# # fn:compare
# $RDF::Query::functions{"http://www.w3.org/2005/04/xpath-functionscompare"}	= sub {
# 	my $query	= shift;
# 	my $nodea	= shift;
# 	my $nodeb	= shift;
# 	my $cast	= 'sop:str';
# 	return ($RDF::Query::functions{$cast}->($query, $nodea) cmp $RDF::Query::functions{$cast}->($query, $nodeb));
# };
# 
# # fn:not
# $RDF::Query::functions{"http://www.w3.org/2005/04/xpath-functionsnot"}	= sub {
# 	my $query	= shift;
# 	my $nodea	= shift;
# 	my $nodeb	= shift;
# 	my $cast	= 'sop:str';
# 	return (0 != ($RDF::Query::functions{$cast}->($query, $nodea) cmp $RDF::Query::functions{$cast}->($query, $nodeb)));
# };

# fn:matches
$RDF::Query::functions{"http://www.w3.org/2005/04/xpath-functionsmatches"}	= sub {
	my $query	= shift;
	my $node	= shift;
	my $match	= shift;
	my $f		= shift;
	
	my $string;
	if ($node->isa('RDF::Query::Node::Resource')) {
		$string	= $node->uri_value;
	} elsif ($node->isa('RDF::Query::Node::Literal')) {
		$string	= $node->literal_value;
	} else {
		throw RDF::Query::Error::TypeError -text => "xpath:matches called without a literal or resource";
	}
	
	my $pattern	= $match->literal_value;
	return undef if (index($pattern, '(?{') != -1);
	return undef if (index($pattern, '(??{') != -1);
	my $flags	= blessed($f) ? $f->literal_value : '';
	
	my $matches;
	if ($flags) {
		$pattern	= "(?${flags}:${pattern})";
		warn 'pattern: ' . $pattern;
		$matches	= $string =~ /$pattern/;
	} else {
		$matches	= ($string =~ /$pattern/) ? 1 : 0;
	}

	return ($matches)
		? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
		: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');

};

# xs:	http://www.w3.org/2001/XMLSchema
# fn:	http://www.w3.org/2005/04/xpath-functions
# xdt:	http://www.w3.org/2005/04/xpath-datatypes
# err:	http://www.w3.org/2004/07/xqt-errors



################################################################################
################################################################################
sub ________CUSTOM_FUNCTIONS________ {}#########################################
################################################################################

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.sha1sum"}	= sub {
	my $query	= shift;
	my $node	= shift;
	require Digest::SHA1;
	
	my $value;
	if ($node->isa('RDF::Query::Node::Literal')) {
		$value	= $node->literal_value;
	} elsif ($node->isa('RDF::Query::Node::Resource')) {
		$value	= $node->uri_value;
	} else {
		throw RDF::Query::Error::TypeError -text => "jena:sha1sum called without a literal or resource";
	}
	my $hash	= Digest::SHA1::sha1_hex( $value );
	return RDF::Query::Node::Literal->new( $hash );
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.now"}	= sub {
	my $query	= shift;
	my $dt		= DateTime->now();
	my $f		= ref($query) ? $query->dateparser : DateTime::Format::W3CDTF->new;
	my $value	= $f->format_datetime( $dt );
	return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.langeq"}	= sub {
	my $query	= shift;
	my $node	= shift;
	my $lang	= shift;
	my $litlang	= $node->literal_value_language;
	my $match	= $lang->literal_value;
	return I18N::LangTags::is_dialect_of( $litlang, $match )
		? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
		: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.listMember"}	= sub {
	my $query	= shift;
	
	my $list	= shift;
	my $value	= shift;
	
	my $first	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' );
	my $rest	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' );
	
	my $result;
	LIST: while ($list) {
		if ($list->is_resource and $list->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil') {
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		} else {
			my $stream	= $query->model->get_statements( $list, $first, undef );
			while (my $stmt = $stream->next()) {
				my $member	= $stmt->object;
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if ($value->equal( $member ));
			}
			
			my $stmt	= $query->model->get_statements( $list, $rest, undef )->next();
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean') unless ($stmt);
			
			my $tail	= $stmt->object;
			if ($tail) {
				$list	= $tail;
				next; #next LIST;
			} else {
				return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
	}
	
	return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
};

$RDF::Query::functions{"sparql:exists"}	= sub {
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
};

$RDF::Query::functions{"sparql:coalesce"}	= sub {
	my $query	= shift;
	my $args	= shift;
	while (defined(my $node = $args->())) {
		if (blessed($node)) {
			return $node;
		}
	}
	return;
};

our $GEO_DISTANCE_LOADED;
BEGIN {
	$GEO_DISTANCE_LOADED	= do {
		eval {
			require Geo::Distance;
		};
		($@) ? 0 : 1;
	};
}
$RDF::Query::functions{"java:com.ldodds.sparql.Distance"}	= sub {
	# http://xmlarmyknife.com/blog/archives/000281.html
	my $query	= shift;
	my ($lat1, $lon1, $lat2, $lon2);
	
	unless ($GEO_DISTANCE_LOADED) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute distance because Geo::Distance is not available" );
	}

	my $geo		= ref($query)
				? ($query->{_query_cache}{'java:com.ldodds.sparql.Distance'}{_geo_dist_obj} ||= new Geo::Distance)
				: new Geo::Distance;
	if (2 == @_) {
		my ($point1, $point2)	= map { $_->literal_value } splice(@_,0,2);
		($lat1, $lon1)	= split(/ /, $point1);
		($lat2, $lon2)	= split(/ /, $point2);
	} else {
		($lat1, $lon1, $lat2, $lon2)	= map { $_->literal_value } splice(@_,0,4);
	}
	
	my $dist	= $geo->distance(
					'kilometer',
					$lon1,
					$lat1,
					$lon2,
					$lat2,
				);
#	warn "ldodds:Distance => $dist\n";
	return RDF::Query::Node::Literal->new("$dist", undef, 'http://www.w3.org/2001/XMLSchema#float');
};

$RDF::Query::functions{"http://kasei.us/2007/09/functions/warn"}	= sub {
	my $query	= shift;
	my $value	= shift;
	my $func	= RDF::Query::Expression::Function->new( 'sparql:str', $value );
	
	my $string	= Dumper( $func->evaluate( undef, undef, {} ) );
	no warnings 'uninitialized';
	warn "FILTER VALUE: $string\n";
	return $value;
};


### func:bloom( ?var, "frozen-bloom-filter" ) => true iff str(?var) is in the bloom filter.
our $BLOOM_FILTER_LOADED;
BEGIN {
	$BLOOM_FILTER_LOADED	= do {
		eval {
			require Bloom::Filter;
		};
		($@)
			? 0
			: (Bloom::Filter->can('thaw'))
				? 1
				: 0;
	};
}
{
	my $BLOOM_URL	= 'http://kasei.us/code/rdf-query/functions/bloom';
	sub _BLOOM_ADD_NODE_MAP_TO_STREAM {
		my $query	= shift;
			my $stream	= shift;
		$l->debug("bloom filter got result stream\n");
		my $nodemap	= $query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' };
		$stream->add_extra_result_data('bnode-map', $nodemap);
	}
	push( @{ $RDF::Query::hooks{ 'http://kasei.us/code/rdf-query/hooks/function_init' } }, sub {
		my $query		= shift;
		my $function	= shift;
		if ($function->uri_value eq $BLOOM_URL) {
			$query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' }	||= {};
			$query->add_hook_once( 'http://kasei.us/code/rdf-query/hooks/post-execute', \&_BLOOM_ADD_NODE_MAP_TO_STREAM, "${BLOOM_URL}#add_node_map" );
		}
	} );
	$RDF::Query::functions{ $BLOOM_URL }	= sub {
		my $query	= shift;
			
		my $value	= shift;
		my $filter	= shift;
		my $bloom;
		
		unless ($BLOOM_FILTER_LOADED) {
			$l->warn("Cannot compute bloom filter because Bloom::Filter is not available");
			throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute bloom filter because Bloom::Filter is not available" );
		}
		
		$l->debug("k:bloom being executed with node " . $value);
		
		if (exists( $query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter } )) {
			$bloom	= $query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter };
		} else {
			my $value	= $filter->literal_value;
			$bloom	= Bloom::Filter->thaw( $value );
			$query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter }	= $bloom;
		}
		
		my $seen	= $query->{_query_cache}{ $BLOOM_URL }{ 'node_name_cache' }	= {};
		die 'kasei:bloom died: no bridge anymore'; # no bridge anymore!
		my $bridge;
		my @names	= RDF::Query::Algebra::Service->_names_for_node( $value, $query, $bridge, {}, {}, 0, '', $seen );
		$l->debug("- " . scalar(@names) . " identity names for node");
		foreach my $string (@names) {
			$l->debug("checking bloom filter for --> '$string'\n");
			my $ok	= $bloom->check( $string );
			$l->debug("-> ok") if ($ok);
			if ($ok) {
				my $nodemap	= $query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' };
				push( @{ $nodemap->{ $value->as_string } }, $string );
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	};
}

$RDF::Query::functions{"http://kasei.us/code/rdf-query/functions/bloom/filter"}	= sub {
	my $query	= shift;
	
	my $value	= shift;
	my $filter	= shift;
	my $bloom;
	
	unless ($BLOOM_FILTER_LOADED) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute bloom filter because Bloom::Filter is not available" );
	}
	
	if (ref($query) and exists( $query->{_query_cache}{ "http://kasei.us/code/rdf-query/functions/bloom/filter" }{ 'filters' }{ $filter } )) {
		$bloom	= $query->{_query_cache}{ "http://kasei.us/code/rdf-query/functions/bloom/filter" }{ 'filters' }{ $filter };
	} else {
		my $value	= $filter->literal_value;
		$bloom	= Bloom::Filter->thaw( $value );
		if (ref($query)) {
			$query->{_query_cache}{ "http://kasei.us/code/rdf-query/functions/bloom/filter" }{ 'filters' }{ $filter }	= $bloom;
		}
	}
	
	my $string	= $value->as_string;
	$l->debug("checking bloom filter for --> '$string'\n");
	my $ok	= $bloom->check( $string );
	$l->debug("-> ok") if ($ok);
	if ($ok) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};



1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
