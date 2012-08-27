package RDF::Trine::Node::Literal;

use utf8;
use Moose;
use MooseX::Aliases;
use RDF::Trine::Types qw(UriStr);
use MooseX::Types::Moose qw(Str);
use namespace::autoclean;

with 'RDF::Trine::Node::API::RDFNode';

has language => (
	is        => 'ro',
	isa       => Str,
	predicate => "has_language",
	traits    => [qw( MooseX::UndefTolerant::Attribute )],
);

has datatype => (
	is        => 'ro',
	isa       => UriStr,
	predicate => "has_datatype",
	traits    => [qw( MooseX::UndefTolerant::Attribute )],
	coerce    => 1,
);

alias $_ => 'value' for qw(literal_value);
alias literal_value_language => 'language';
alias literal_datatype => 'datatype';

sub BUILDARGS {
	if (@_ >= 2 and @_ <= 4 and not ref $_[1]) {
		return +{
			value    => $_[1],
			language => $_[2],
			datatype => $_[3],
		};
	}
	my $class = shift;
	(@_==1 and ref $_[0] eq 'HASH')
		? $class->SUPER::BUILDARGS(@_)
		: $class->SUPER::BUILDARGS(+{@_})
}

my %SUBCLASS;

# This is not really intended as a third-party extensibility point.
# It's really for Trine-internal use.
sub _register_datatype {
	my ($datatype, $sc) = @_;
	$datatype = $datatype->value if blessed $datatype;
	$SUBCLASS{ $datatype } ||= $sc;
}

require RDF::Trine::Node::Literal::Boolean;
require RDF::Trine::Node::Literal::Integer;

{
	package RDF::Trine::Node::Literal::Exception::NotPossible;
	use Moose;
	extends 'RDF::Trine::Exception';
	has literal => (is => 'ro');
}

sub BUILD {
	my $self = shift;
	
	RDF::Trine::Node::Literal::Exception::NotPossible->throw(
		message => "cannot have both a language and datatype",
		literal => $self,
	) if $self->has_datatype && $self->has_language;
	
	if (my $r = $SUBCLASS{ $self->datatype }) {
		$r->meta->rebless_instance($self);
	}
}

sub new_canonical {
	my $class = shift;
	my $self  = $class->new(@_);
	if ($self->does('Trine::Role::Canonicalization')) {
		return $self->canonicalize;
	}
	return $self;
}

sub type {
	'LITERAL'
}

sub as_ntriples {
	my $self = shift;
	return sprintf("\"%s\"^^<%s>", $self->_escaped_value, $self->datatype)
		if $self->has_datatype;
	return sprintf("\"%s\"\@%s", $self->_escaped_value, $self->language)
		if $self->has_language;
	return sprintf("\"%s\"", $self->_escaped_value);
}

sub is_literal { 1 }

my $numeric_datatypes = qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>;
sub is_numeric_type {
	my $self = shift;
	$self->has_datatype and $self->literal_datatype =~ $numeric_datatypes;
}


# NO-OP stuff
use constant is_valid_lexical_form => 1;
sub canonical_lexical_form { shift->value };
use constant is_canonical_lexical_form => 1;
sub canonicalize { shift };
use constant numeric_value => undef;

1;

__END__
sub canonicalize_literal_value {
	my $self	= shift;
	my $value	= shift;
	my $dt		= shift;
	my $warn	= shift;
	
	if ($dt eq 'http://www.w3.org/2001/XMLSchema#integer') {
		if ($value =~ m/^([-+])?(\d+)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(\d)/$1/;
			return "${sign}${num}";
		} else {
			warn "Bad lexical form for xsd:integer: '$value'" if ($warn);
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)([.]\d*)?)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			my $int		= $3;
			my $frac	= $4;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(.)/$1/;
			$num		=~ s/[.](\d)0+$/.$1/;
			if ($num =~ /^[.]/) {
				$num	= "0$num";
			}
			if ($num !~ /[.]/) {
				$num	= "${num}.0";
			}
			return "${sign}${num}";
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} else {
			warn "Bad lexical form for xsd:deciaml: '$value'" if ($warn);
			$value		= sprintf('%f', $value);
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/) {
			my $sign	= $1;
			my $inf		= $4;
			my $nan		= $5;
			no warnings 'uninitialized';
			$sign		= '' if ($sign eq '+');
			return "${sign}$inf" if ($inf);
			return $nan if ($nan);

			$value		= sprintf('%E', $value);
			$value 		=~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/;
			$sign		= $1;
			$inf		= $4;
			$nan		= $5;
			my $num		= $2;
			my $exp		= $3;
			$num		=~ s/[.](\d+?)0+/.$1/;
			$exp	=~ tr/e/E/;
			$exp	=~ s/E[+]/E/;
			$exp	=~ s/E(-?)0+([1-9])$/E$1$2/;
			$exp	=~ s/E(-?)0+$/E${1}0/;
			return "${sign}${num}${exp}";
		} else {
			warn "Bad lexical form for xsd:float: '$value'" if ($warn);
			$value	= sprintf('%E', $value);
			$value	=~ s/E[+]/E/;
			$value	=~ s/E0+(\d)/E$1/;
			$value	=~ s/(\d)0+E/$1E/;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/) {
			my $sign	= $1;
			my $inf		= $4;
			my $nan		= $5;
			no warnings 'uninitialized';
			$sign		= '' if ($sign eq '+');
			return "${sign}$inf" if ($inf);
			return $nan if ($nan);

			$value		= sprintf('%E', $value);
			$value 		=~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/;
			$sign		= $1;
			$inf		= $4;
			$nan		= $5;
			my $num		= $2;
			my $exp		= $3;
			$num		=~ s/[.](\d+?)0+/.$1/;
			$exp	=~ tr/e/E/;
			$exp	=~ s/E[+]/E/;
			$exp	=~ s/E(-?)0+([1-9])$/E$1$2/;
			$exp	=~ s/E(-?)0+$/E${1}0/;
			return "${sign}${num}${exp}";
		} else {
			warn "Bad lexical form for xsd:double: '$value'" if ($warn);
			$value	= sprintf('%E', $value);
			$value	=~ s/E[+]/E/;
			$value	=~ s/E0+(\d)/E$1/;
			$value	=~ s/(\d)0+E/$1E/;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false|0|1)$/) {
			$value	= 'true' if ($value eq '1');
			$value	= 'false' if ($value eq '0');
			return $value;
		} else {
			warn "Bad lexical form for xsd:boolean: '$value'" if ($warn);
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			# XXX need to canonicalize the dateTime
			return $value;
		} else {
			warn "Bad lexical form for xsd:boolean: '$value'" if ($warn);
		}
	}
	return $value;
}

sub is_canonical_lexical_form {
	my $self	= shift;
	my $value	= $self->literal_value;
	my $dt		= $self->literal_datatype;
	
	unless ($dt =~ qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|boolean|dateTime|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		return '0E0';	# zero but true (it's probably ok, but we don't recognize the datatype)
	}
	
	if ($dt =~ m<http://www.w3.org/2001/XMLSchema#(integer|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		if ($value =~ m/^([-+])?(\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)[.]\d+)$/) {
			return 1;
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^[-+]?(\d+\.\d*|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} elsif ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^[-+]?((\d+(\.\d*))|(\.\d+))([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} elsif ($value =~ m/^[-+]?((\d+(\.\d*)?)|(\.\d+))([Ee][-+]?\d+)|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			return 1;
		} else {
			return 0;
		}
	}
	return 0;
}

sub is_valid_lexical_form {
	my $self	= shift;
	my $value	= $self->literal_value;
	my $dt		= $self->literal_datatype;
	
	unless ($dt =~ qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|boolean|dateTime|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		return '0E0';	# zero but true (it's probably ok, but we don't recognize the datatype)
	}
	
	if ($dt =~ m<http://www.w3.org/2001/XMLSchema#(integer|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		if ($value =~ m/^([-+])?(\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)([.]\d*)?)$/) {
			return 1;
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^[-+]?((\d+(\.\d*)?)|(\.\d+))([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false|0|1)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			return 1;
		} else {
			return 0;
		}
	}
	return 0;
}

sub numeric_value {
	my $self	= shift;
	if ($self->is_numeric_type) {
		my $value	= $self->literal_value;
		if (looks_like_number($value)) {
			my $v	= 0 + eval "$value";
			return $v;
		} else {
			throw RDF::Query::Error::TypeError -text => "Literal with numeric type does not appear to have numeric value.";
		}
	} elsif (not $self->has_datatype) {
		if (looks_like_number($self->literal_value)) {
			return 0+$self->literal_value;
		} else {
			return;
		}
	} elsif ($self->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		return ($self->literal_value eq 'true') ? 1 : 0;
	} else {
		return;
	}
}

