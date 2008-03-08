# RDF::Query::Functions
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Functions - Standard Extension Functions

=cut

package RDF::Query::Functions;

use strict;
use warnings;
no warnings 'redefine';

use Scalar::Util qw(blessed reftype looks_like_number);

use RDF::Query;
use RDF::Query::Model::RDFTrine;
use RDF::Query::Error qw(:try);

use Bloom::Filter;
use Data::Dumper;
use MIME::Base64;
use Storable qw(thaw);
use Digest::SHA1 qw(sha1_hex);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################


### XSD CASTING FUNCTIONS

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#integer"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value;
	if ($node->is_literal) {
		my $type	= $node->literal_datatype || '';
		$value		= $node->literal_value;
		if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
			$value	= ($value eq 'true') ? '1' : '0';
		} elsif ($node->is_numeric_type) {
			if ($type eq 'http://www.w3.org/2001/XMLSchema#double') {
				throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot to xsd:integer as precision would be lost" );
			} elsif (int($value) != $value) {
				throw RDF::Query::Error::FilterEvaluationError ( -text => "cannot to xsd:integer as precision would be lost" );
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
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
	my $node	= shift;
	my $f		= ref($query) ? $query->{dateparser} : DateTime::Format::W3CDTF->new;
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
	my $bridge	= shift;
	
	my $node	= shift;
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

$RDF::Query::functions{"sparql:logical-or"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	### Arguments to sparql:logical-* functions are passed lazily via a closure
	### so that TypeErrors in arguments can be handled properly.
	my $args	= shift;
	
	my $bool	= RDF::Query::Node::Resource->new( "sparql:ebv" );
	my ($bool1, $bool2, $error);
	try {
		my $arg1 	= $args->();
		my $func	= RDF::Query::Algebra::Expr::Function->new( $bool, $arg1 );
		my $value	= $func->evaluate( $query, $bridge, {} );
		$bool1		= ($value->literal_value eq 'true') ? 1 : 0;
	} otherwise {
		warn "error in lhs of logical-or" if ($debug);
		$error	= shift;
	};
	try {
		my $arg2 	= $args->();
		my $func	= RDF::Query::Algebra::Expr::Function->new( $bool, $arg2 );
		my $value	= $func->evaluate( $query, $bridge, {} );
		$bool2		= ($value->literal_value eq 'true') ? 1 : 0;
	} otherwise {
		warn "error in rhs of logical-or" if ($debug);
		$error	= shift;
	};
	
	if ($bool1 or $bool2) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} elsif ($error) {
		$error->throw;
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sop:logical-and
$RDF::Query::functions{"sparql:logical-and"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	### Arguments to sparql:logical-* functions are passed lazily via a closure
	### so that TypeErrors in arguments can be handled properly.
	my $args	= shift;
	
	my $bool	= RDF::Query::Node::Resource->new( "sparql:ebv" );
	my ($bool1, $bool2, $error);
	try {
		my $arg1 = $args->();
		my $func	= RDF::Query::Algebra::Expr::Function->new( $bool, $arg1 );
		my $value	= $func->evaluate( $query, $bridge, {} );
		$bool1		= ($value->literal_value eq 'true') ? 1 : 0;
	} otherwise {
		$error	= shift;
	};
	try {
		my $arg2 = $args->();
		my $func	= RDF::Query::Algebra::Expr::Function->new( $bool, $arg2 );
		my $value	= $func->evaluate( $query, $bridge, {} );
		$bool2		= ($value->literal_value eq 'true') ? 1 : 0;
	} otherwise {
		$error	= shift;
	};
	
	if ($bool1 and $bool2) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} elsif ($error) {
		$error->throw;
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sop:isBound
$RDF::Query::functions{"sparql:bound"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
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
	my $bridge	= shift;
	my $node	= shift;
	if ($node->is_resource) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sop:isBlank
$RDF::Query::functions{"sparql:isblank"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	if ($node->is_blank) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};

# sop:isLiteral
$RDF::Query::functions{"sparql:isliteral"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	if ($node->is_literal) {
		return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	} else {
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	}
};


$RDF::Query::functions{"sparql:lang"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
	my $node	= shift;
	if ($node->is_literal) {
		if ($node->has_language) {
			throw RDF::Query::Error::TypeError ( -text => "cannot call datatype() on a language-tagged literal" );
		} elsif ($node->has_datatype) {
			my $type	= $node->literal_datatype;
			warn "datatype => $type" if ($debug);
			return RDF::Query::Node::Resource->new($type);
		} else {
			warn 'datatype => string' if ($debug);
			return RDF::Query::Node::Resource->new('http://www.w3.org/2001/XMLSchema#string');
		}
	} else {
		throw RDF::Query::Error::TypeError ( -text => "cannot call datatype() on a non datatyped node" );
	}
};

$RDF::Query::functions{"sparql:regex"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $match	= shift;
	
	unless ($node->is_literal) {
		throw RDF::Query::Error::TypeError ( -text => 'REGEX() called with non-string data' );
	}
	
	my $text	= $node->literal_value;
	my $pattern	= $match->literal_value;
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

# fn:compare
$RDF::Query::functions{"http://www.w3.org/2005/04/xpath-functionscompare"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:str';
	return ($RDF::Query::functions{$cast}->($query, $nodea) cmp $RDF::Query::functions{$cast}->($query, $nodeb));
};

# fn:not
$RDF::Query::functions{"http://www.w3.org/2005/04/xpath-functionsnot"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:str';
	return (0 != ($RDF::Query::functions{$cast}->($query, $nodea) cmp $RDF::Query::functions{$cast}->($query, $nodeb)));
};

# fn:matches
$RDF::Query::functions{"http://www.w3.org/2005/04/xpath-functionsmatches"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
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
	my $bridge	= shift;
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
	my $bridge	= shift;
	my $dt		= DateTime->now();
	my $f		= ref($query) ? $query->{dateparser} : DateTime::Format::W3CDTF->new;
	my $value	= $f->format_datetime( $dt );
	return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.langeq"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	require I18N::LangTags;
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
	my $bridge	= shift;
	
	my $list	= shift;
	my $value	= shift;
	
	my $first	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' );
	my $rest	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' );
	
	my $result;
	LIST: while ($list) {
		if ($list->is_resource and $list->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil') {
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		} else {
			my $stream	= $bridge->get_statements( $list, $first, undef );
			while (my $stmt = $stream->next()) {
				my $member	= $stmt->object;
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if ($value->equal( $member ));
			}
			
			my $stmt	= $bridge->get_statements( $list, $rest, undef )->next();
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
	my $bridge	= shift;
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
	my $bridge	= shift;
	my $value	= shift;
	my $func	= RDF::Query::Algebra::Expr::Function->new( 'sparql:str', $value );
	
	my $string	= Dumper( $func->evaluate( undef, undef, {} ) );
	no warnings 'uninitialized';
	warn "FILTER VALUE: $string\n";
	return $value;
};


### func:bloom( ?var, "frozen-bloom-filter" ) => true iff str(?var) is in the bloom filter.
{
	my $BLOOM_URL	= 'http://kasei.us/code/rdf-query/functions/bloom';
	sub BLOOM_ADD_NODE_MAP_TO_STREAM {
		my $query	= shift;
		my $bridge	= shift;
		my $stream	= shift;
		warn "bloom filter got result stream\n" if ($debug);
		my $nodemap	= $query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' };
		$stream->add_extra_result_data('bnode-map', $nodemap);
	}
	RDF::Query->add_hook('http://kasei.us/code/rdf-query/hooks/function_init', sub {
		my $query		= shift;
		my $function	= shift;
		warn "function init: " . $function->uri_value if ($debug);
		$query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' }	= {};
		if ($function->uri_value eq $BLOOM_URL) {
			warn "adding bloom filter result stream hook" if ($debug);
			$query->add_hook( 'http://kasei.us/code/rdf-query/hooks/post-execute', \&BLOOM_ADD_NODE_MAP_TO_STREAM, "${BLOOM_URL}#add_node_map" );
		}
	});
	$RDF::Query::functions{"http://kasei.us/code/rdf-query/functions/bloom"}	= sub {
		my $query	= shift;
		my $bridge	= shift;
		
		my $value	= shift;
		my $filter	= shift;
		my $bloom;
		
		if (exists( $query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter } )) {
			$bloom	= $query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter };
		} else {
			my $value	= $filter->literal_value;
			$bloom	= Bloom::Filter->thaw( $value );
			$query->{_query_cache}{ $BLOOM_URL }{ 'filters' }{ $filter }	= $bloom;
		}
		
		my @names	= RDF::Query::Algebra::Service->_names_for_node( $value, $query, $bridge, {}, 0 );
		foreach my $string (@names) {
			warn "checking bloom filter for --> '$string'\n" if ($debug);
			my $ok	= $bloom->check( $string );
			warn "-> ok\n" if ($ok and $debug);
			if ($ok) {
				push( @{ $query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' }{ $value->as_string } }, $string );
				warn Dumper($query->{_query_cache}{ $BLOOM_URL }{ 'nodemap' });
				return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
			}
		}
		return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
	};
}
1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
