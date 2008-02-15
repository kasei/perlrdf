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

use Scalar::Util qw(blessed reftype looks_like_number);
use RDF::Query::Error qw(:try);

use Data::Dumper;
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 1;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################


### XSD CASTING FUNCTIONS

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#integer"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value;
	if ($bridge->is_literal($node)) {
		my $type	= $bridge->literal_datatype( $node ) || '';
		$value		= $bridge->literal_value( $node );
		if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
			$value	= ($value eq 'true') ? '1' : '0';
		}
	} elsif ($bridge->is_resource($node)) {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:integer" );
	}
	
	if (looks_like_number($value)) {
		if ($value == int($value)) {
			$value	= int($value);
		} else {
			throw RDF::Query::Error::TypeError ( -text => "cannot cast a non-integral value to xsd:integer" );
		}
	} else {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:integer" );
	}
	
	return $bridge->new_literal( "$value", undef, 'http://www.w3.org/2001/XMLSchema#integer' );
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#decimal"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value;
	if ($bridge->is_literal($node)) {
		my $type	= $bridge->literal_datatype( $node ) || '';
		$value		= $bridge->literal_value( $node );
		if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
			$value	= ($value eq 'true') ? '1.0' : '0.0';
		}
	} elsif ($bridge->is_resource($node)) {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:integer" );
	}
	
	if (looks_like_number($value)) {
		$value	= +$node;
	} else {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:decimal" );
	}
	
	return $bridge->new_literal( sprintf("%f", $value), undef, 'http://www.w3.org/2001/XMLSchema#decimal' );
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#float"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value;
	if ($bridge->is_literal($node)) {
		my $type	= $bridge->literal_datatype( $node ) || '';
		$value		= $bridge->literal_value( $node );
		if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
			$value	= ($value eq 'true') ? 1.0E0 : 0.0E0;
		}
	} elsif ($bridge->is_resource($node)) {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:float" );
	}
	
	if (looks_like_number($value)) {
		$value	= int($node);
	} else {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:float" );
	}
	
	return $bridge->new_literal( sprintf("%e", $value), undef, 'http://www.w3.org/2001/XMLSchema#float' );
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#double"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value;
	if ($bridge->is_literal($node)) {
		my $type	= $bridge->literal_datatype( $node ) || '';
		$value		= $bridge->literal_value( $node );
		if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
			$value	= ($value eq 'true') ? 1.0E0 : 0.0E0;
		}
	} elsif ($bridge->is_resource($node)) {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast an IRI to xsd:double" );
	}
	
	if (looks_like_number($value)) {
		$value	= int($node);
	} else {
		throw RDF::Query::Error::TypeError ( -text => "cannot cast unrecognized value '$value' to xsd:double" );
	}
	
	return $bridge->new_literal( sprintf("%e", $value), undef, 'http://www.w3.org/2001/XMLSchema#double' );
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#boolean"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value	= (blessed($node)) ? $bridge->literal_value( $node ) : $node;
	no warnings 'uninitialized';
	return $bridge->new_literal('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if ($value eq 'true');
	return $bridge->new_literal('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if ($value eq 'false');
	throw RDF::Query::Error::FilterEvaluationError ( -text => "'$node' is not a boolean type (true or false)" );
};

$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#string"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $value	= $query->get_value( $node, bridge => $bridge );
	return $bridge->new_literal($value, undef, 'http://www.w3.org/2001/XMLSchema#string');
};

$RDF::Query::functions{"sop:boolean"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	return 0 if not defined($node);
	
	if (ref($node)) {
		if ($bridge->is_literal($node)) {
			my $value	= $bridge->literal_value( $node );
			my $type	= $bridge->literal_datatype( $node );
			if ($type) {
				if ($type eq 'http://www.w3.org/2001/XMLSchema#boolean') {
#					warn "boolean-typed: $value";
					return 0 if ($value eq 'false');
					return 1 if ($value eq 'true');
					throw RDF::Query::Error::FilterEvaluationError ( -text => "'$value' is not a boolean type (true or false)" );
				} elsif ($type eq 'http://www.w3.org/2001/XMLSchema#string') {
#					warn "string-typed: $value";
					return 0 if (length($value) == 0);
					return 1;
				} elsif (RDF::Query::is_numeric_type( $type )) {
#					warn "numeric-typed: $value";
					return ($value == 0) ? 0 : 1;
				} else {
#					warn "unknown-typed: $value";
					throw RDF::Query::Error::TypeError ( -text => "'$value' cannot be coerced into a boolean value" );
				}
			} else {
				no warnings 'numeric';
				no warnings 'uninitialized';
#				warn "not-typed: $value";
				return 0 if (length($value) == 0);
				if (looks_like_number($value) and $value == 0) {
					return 0;
				} else {
					return 1;
				}
			}
		}
		throw RDF::Query::Error::TypeError;
	} else {
		return $node ? 1 : 0;
	}
};

$RDF::Query::functions{"sop:date"}	= 
$RDF::Query::functions{"http://www.w3.org/2001/XMLSchema#dateTime"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $f		= $query->{dateparser};
	my $date	= $RDF::Query::functions{'sop:str'}->( $query, $bridge, $node );
	my $dt		= eval { $f->parse_datetime( $date ) };
#	if ($@) {
#		warn $@;
#	}
	return $dt;
};


$RDF::Query::functions{"sop:numeric"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	if ($bridge->is_literal($node)) {
		my $value	= $bridge->literal_value( $node );
		my $type	= $bridge->literal_datatype( $node );
		if ($type and $type eq 'http://www.w3.org/2001/XMLSchema#integer') {
			return int($value)
		}
		return +$value;
	} elsif (looks_like_number($node)) {
		return $node;
	} else {
		return 0;
	}
};

$RDF::Query::functions{"sparql:str"}	=
$RDF::Query::functions{"sop:str"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	Carp::confess unless (blessed($bridge));	# XXXassert
	Carp::confess unless ($bridge->isa('RDF::Query::Model'));	# XXXassert
	
	my $node	= shift;
	if ($bridge->is_literal($node)) {
		my $value	= $bridge->literal_value( $node );
		my $type	= $bridge->literal_datatype( $node );
		return $value;
	} elsif ($bridge->is_resource($node)) {
		return $bridge->uri_value($node);
	} elsif ($bridge->is_blank($node)) {
		return $bridge->blank_identifier($node);
	} elsif (not defined reftype($node)) {
		return $node;
	} else {
		return '';
	}
};

$RDF::Query::functions{"sop:lang"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	if ($bridge->is_literal($node)) {
		my $lang	= $bridge->literal_value_language( $node );
		return $lang;
	}
	return '';
};

# sop:logical-or
$RDF::Query::functions{"sop:logical-or"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:boolean';
	return ($RDF::Query::functions{$cast}->( $query, $nodea ) || $RDF::Query::functions{$cast}->( $query, $nodeb ));
};

# sop:logical-and
$RDF::Query::functions{"sop:logical-and"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:boolean';
	return ($RDF::Query::functions{$cast}->( $query, $nodea ) && $RDF::Query::functions{$cast}->( $query, $nodeb ));
};

# sop:isBound
$RDF::Query::functions{"sparql:bound"}	=
$RDF::Query::functions{"sop:isBound"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $bound	= ref($node) ? 1 : 0;
	return $bound;
};

# sop:isURI
$RDF::Query::functions{"sparql:isuri"}	=
$RDF::Query::functions{"sop:isURI"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	return $bridge->is_resource( $node );
};

# sop:isIRI
$RDF::Query::functions{"sparql:isiri"}	=
$RDF::Query::functions{"sop:isIRI"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	return $bridge->is_resource( $node );
};

# sop:isBlank
$RDF::Query::functions{"sparql:isblank"}	=
$RDF::Query::functions{"sop:isBlank"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	return $bridge->is_blank( $node );
};

# sop:isLiteral
$RDF::Query::functions{"sparql:isliteral"}	=
$RDF::Query::functions{"sop:isLiteral"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	return $bridge->is_literal( $node );
};


$RDF::Query::functions{"sparql:lang"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	unless ($bridge->is_literal( $node )) {
		throw RDF::Query::Error::TypeError ( -text => "cannot call lang() on a non-literal value" );
	}
	my $lang	= $bridge->literal_value_language( $node ) || '';
	return $lang;
};

$RDF::Query::functions{"sparql:langmatches"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	my $match	= shift;
	
	{
		my $lang	= $query->get_value( $node, bridge => $bridge );
		my $match	= $query->get_value( $match, bridge => $bridge );
		return undef unless (defined $lang);
		return $query->_false unless ($lang);
		if ($match eq '*') {
			# """A language-range of "*" matches any non-empty language-tag string."""
			return $query->_true;
		} else {
			return (I18N::LangTags::is_dialect_of( $lang, $match )) ? $query->_true : $query->_false;
		}
	}
};

$RDF::Query::functions{"sparql:sameTerm"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $same	= $bridge->equals( $nodea, $nodeb );
	return $same;
};

$RDF::Query::functions{"sop:datatype"}	=
$RDF::Query::functions{"sparql:datatype"}	= sub {
	# """Returns the datatype IRI of typedLit; returns xsd:string if the parameter is a simple literal."""
	my $query	= shift;
	my $bridge	= shift;
	my $node	= shift;
	return '' unless (blessed($node));
	if ($node->isa('DateTime')) {
		return 'http://www.w3.org/2001/XMLSchema#dateTime';
	} elsif ($bridge->is_literal($node)) {
		my $lang	= $bridge->literal_value_language( $node );
		if ($lang) {
			throw RDF::Query::Error::TypeError ( -text => "cannot call datatype() on a language-tagged literal" );
		}
		my $type	= $bridge->literal_datatype( $node );
		if ($type) {
			return $type;
		} elsif (not $bridge->literal_value_language( $node )) {
			return 'http://www.w3.org/2001/XMLSchema#string';
		} else {
			return '';
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
	
	my $text	= $query->get_value( $node, bridge => $bridge );
	my $pattern	= $query->get_value( $match, bridge => $bridge );
	if (@_) {
		my $data	= shift;
		my $flags	= $query->get_value( $data, bridge => $bridge );
		if ($flags !~ /^[smix]*$/) {
			throw RDF::Query::Error::FilterEvaluationError ( -text => 'REGEX() called with unrecognized flags' );
		}
		$pattern	= qq[(?${flags}:$pattern)];
	}
	if ($bridge->is_literal($text)) {
		$text	= $bridge->literal_value( $text );
	} elsif (blessed($text)) {
		throw RDF::Query::Error::TypeError ( -text => 'REGEX() called with non-string data' );
	}
	
	return ($text =~ /$pattern/)
};

# op:dateTime-equal
$RDF::Query::functions{"op:dateTime-equal"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:date';
	return ($RDF::Query::functions{$cast}->( $query, $nodea ) == $RDF::Query::functions{$cast}->( $query, $nodeb ));
};

# op:dateTime-less-than
$RDF::Query::functions{"op:dateTime-less-than"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:date';
	return ($RDF::Query::functions{$cast}->( $query, $nodea ) < $RDF::Query::functions{$cast}->( $query, $nodeb ));
};

# op:dateTime-greater-than
$RDF::Query::functions{"op:dateTime-greater-than"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:date';
	return ($RDF::Query::functions{$cast}->($query, $nodea) > $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-equal
$RDF::Query::functions{"op:numeric-equal"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) == $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-less-than
$RDF::Query::functions{"op:numeric-less-than"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) < $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-greater-than
$RDF::Query::functions{"op:numeric-greater-than"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) > $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-multiply
$RDF::Query::functions{"op:numeric-multiply"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) * $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-divide
$RDF::Query::functions{"op:numeric-divide"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) / $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-add
$RDF::Query::functions{"op:numeric-add"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) + $RDF::Query::functions{$cast}->($query, $nodeb));
};

# op:numeric-subtract
$RDF::Query::functions{"op:numeric-subtract"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $nodea	= shift;
	my $nodeb	= shift;
	my $cast	= 'sop:numeric';
	return ($RDF::Query::functions{$cast}->($query, $nodea) - $RDF::Query::functions{$cast}->($query, $nodeb));
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
	my $cast	= 'sop:str';
	my $string	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
	my $pattern	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
	return undef if (index($pattern, '(?{') != -1);
	return undef if (index($pattern, '(??{') != -1);
	my $flags	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
	if ($flags) {
		$pattern	= "(?${flags}:${pattern})";
		return $string =~ /$pattern/;
	} else {
		return ($string =~ /$pattern/) ? 1 : 0;
	}
};

# sop:	http://www.w3.org/TR/rdf-sparql-query/
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
	my $cast	= 'sop:str';
	return Digest::SHA1::sha1_hex($RDF::Query::functions{$cast}->($query, $bridge, $node));
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.now"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $dt		= DateTime->new();
	return $dt;
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.langeq"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $cast	= 'sop:str';
	
	require I18N::LangTags;
	my $node	= shift;
	my $lang	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
	my $litlang	= $bridge->literal_value_language( $node );
	
	return I18N::LangTags::is_dialect_of( $litlang, $lang );
};

$RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.listMember"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	
	my $list	= shift;
	my $value	= shift;
	if ($bridge->is_resource( $list ) and $bridge->uri_value( $list ) eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil') {
		return 0;
	} else {
		my $first	= $bridge->new_resource( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' );
		my $rest	= $bridge->new_resource( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' );
		my $stream	= $bridge->get_statements( $list, $first, undef );
		while (my $stmt = $stream->()) {
			my $member	= $bridge->object( $stmt );
			return 1 if ($bridge->equals( $value, $member ));
		}
		
		my $stmt	= $bridge->get_statements( $list, $rest, undef )->();
		my $tail	= $bridge->object( $stmt );
		if ($tail) {
			return $RDF::Query::functions{"java:com.hp.hpl.jena.query.function.library.listMember"}->( $query, $bridge, $tail, $value );
		} else {
			return 0;
		}
	}
};

$RDF::Query::functions{"java:com.ldodds.sparql.Distance"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my ($lat1, $lon1, $lat2, $lon2);
	
	eval { require Geo::Distance };
	if ($@) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => "Cannot compute distance because Geo::Distance is not available" );
	}
	
	my $cast	= 'sop:str';
	if (2 == @_) {
		my $point1	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
		my $point2	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
		($lat1, $lon1)	= split(/ /, $point1);
		($lat2, $lon2)	= split(/ /, $point2);
	} else {
		$lat1	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
		$lon1	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
		$lat2	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
		$lon2	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
	}
	
	my $geo		= new Geo::Distance;
	my $dist	= $geo->distance(
					'kilometer',
					$lon1,
					$lat1,
					$lon2,
					$lat2,
				);
	return $bridge->new_literal("$dist", undef, 'http://www.w3.org/2001/XMLSchema#float');
};

$RDF::Query::functions{"http://kasei.us/2007/09/functions/warn"}	= sub {
	my $query	= shift;
	my $bridge	= shift;
	my $cast	= 'sop:str';
	my $value	= $RDF::Query::functions{$cast}->( $query, $bridge, shift );
	no warnings 'uninitialized';
	warn "FILTER VALUE: $value\n";
	return $value;
};


1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
