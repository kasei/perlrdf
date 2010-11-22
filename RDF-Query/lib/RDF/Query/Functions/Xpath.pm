=head1 NAME

RDF::Query::Functions::Xpath - XPath functions

=head1 VERSION

This document describes RDF::Query::Functions::Xpath version 2.904_01.

=head1 DESCRIPTION

Defines the following function:

=over

=item * http://www.w3.org/2005/04/xpath-functionsmatches

=back

=cut

package RDF::Query::Functions::Xpath;

use strict;
use warnings;
use Log::Log4perl;
use POSIX;
use URI::Escape;

use RDF::Trine::Namespace qw(xsd);

our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.xpath");
	$VERSION	= '2.904_01';
}

use Scalar::Util qw(blessed reftype refaddr looks_like_number);

=begin private

=item C<< install >>

Documented in L<RDF::Query::Functions>.

=end private

=cut

sub install {
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
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#matches"}	= sub {
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

	# fn:abs
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#abs"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
			my $value	= $node->numeric_value;
			return RDF::Query::Node::Literal->new( abs($value), undef, $node->literal_datatype );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:abs called without a numeric literal";
		}
	};
	
	# fn:ceiling
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#ceiling"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
			my $value	= $node->numeric_value;
			return RDF::Query::Node::Literal->new( ceil($value), undef, $node->literal_datatype );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:ceiling called without a numeric literal";
		}
	};
	
	# fn:floor
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#floor"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
			my $value	= $node->numeric_value;
			return RDF::Query::Node::Literal->new( floor($value), undef, $node->literal_datatype );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:floor called without a numeric literal";
		}
	};
	
	# fn:round
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#round"}	= sub {
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
			throw RDF::Query::Error::TypeError -text => "xpath:round called without a numeric literal";
		}
	};
	
	# fn:round-half-to-even
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#round-half-to-even"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal') and $node->is_numeric_type) {
			my $value	= $node->numeric_value;
			return RDF::Query::Node::Literal->new( sprintf('%.0f', $value), undef, $node->literal_datatype );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:round-half-to-even called without a numeric literal";
		}
	};
	
	# fn:compare
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#compare"}	= sub {
		my $query	= shift;
		my $node	= shift;
		########################################################################
		throw RDF::Query::Error::ExecutionError -text => "xpath:compare not implemented";
	};
	
	# fn:concat
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#concat"}	= sub {
		my $query	= shift;
		my $node	= shift;
		########################################################################
		throw RDF::Query::Error::ExecutionError -text => "xpath:concat not implemented";
	};
	
	# fn:substring
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#substring"}	= sub {
		my $query	= shift;
		my $node	= shift;
		########################################################################
		throw RDF::Query::Error::ExecutionError -text => "xpath:substring not implemented";
	};
	
	# fn:string-length
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#string-length"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			my $value	= $node->literal_value;
			return RDF::Query::Node::Literal->new( length($value), undef, $xsd->integer );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:string-length called without a literal term";
		}
	};
	
	# fn:upper-case
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#upper-case"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			my $value	= $node->literal_value;
			return RDF::Query::Node::Literal->new( uc($value) );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:upper-case called without a literal term";
		}
	};
	
	# fn:lower-case
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#lower-case"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			my $value	= $node->literal_value;
			return RDF::Query::Node::Literal->new( lc($value) );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:lower-case called without a literal term";
		}
	};
	
	# fn:encode-for-uri
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#encode-for-uri"}	= sub {
		my $query	= shift;
		my $node	= shift;
		if (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			my $value	= $node->literal_value;
			return RDF::Query::Node::Literal->new( uri_escape($value) );
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:escape-for-uri called without a literal term";
		}
	};
	
	# fn:contains
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#contains"}	= sub {
		my $query	= shift;
		my $node	= shift;
		my $pat		= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:contains called without a literal arg1 term";
		}
		unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:contains called without a literal arg2 term";
		}
		my $lit		= $node->literal_value;
		my $plit	= $pat->literal_value;
		my $pos		= index($lit, $plit);
		if ($pos >= 0) {
			return RDF::Query::Node::Literal->new('true', undef, $xsd->boolean);
		} else {
			return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
		}
	};
	
	# fn:starts-with
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#starts-with"}	= sub {
		my $query	= shift;
		my $node	= shift;
		my $pat		= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:starts-with called without a literal arg1 term";
		}
		unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:starts-with called without a literal arg2 term";
		}
		if (index($node->literal_value, $pat->literal_value) == 0) {
			return RDF::Query::Node::Literal->new('true', undef, $xsd->boolean);
		} else {
			return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
		}
	};
	
	# fn:ends-with
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#ends-with"}	= sub {
		my $query	= shift;
		my $node	= shift;
		my $pat		= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:ends-with called without a literal arg1 term";
		}
		unless (blessed($pat) and $pat->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:ends-with called without a literal arg2 term";
		}
		
		my $lit		= $node->literal_value;
		my $plit	= $pat->literal_value;
		my $pos	= length($lit) - length($plit);
		if (rindex($lit, $plit) == $pos) {
			return RDF::Query::Node::Literal->new('true', undef, $xsd->boolean);
		} else {
			return RDF::Query::Node::Literal->new('false', undef, $xsd->boolean);
		}
	};
	
	# op:dateTime-equal
	# op:dateTime-less-than
	# op:dateTime-greater-than
	
	# fn:year-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#year-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:year-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			return RDF::Query::Node::Literal->new($dt->year);
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:year-from-dateTime called without a valid dateTime";
		}
	};
	
	# fn:month-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#month-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:month-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			return RDF::Query::Node::Literal->new($dt->month);
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:month-from-dateTime called without a valid dateTime";
		}
	};
	
	# fn:day-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#day-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:day-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			return RDF::Query::Node::Literal->new($dt->day);
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:day-from-dateTime called without a valid dateTime";
		}
	};
	
	# fn:hours-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#hours-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:hours-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			return RDF::Query::Node::Literal->new($dt->hour);
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:hours-from-dateTime called without a valid dateTime";
		}
	};
	
	# fn:minutes-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#minutes-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:minutes-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			return RDF::Query::Node::Literal->new($dt->minute);
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:minutes-from-dateTime called without a valid dateTime";
		}
	};
	
	# fn:seconds-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#seconds-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:seconds-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			return RDF::Query::Node::Literal->new($dt->second);
		} else {
			throw RDF::Query::Error::TypeError -text => "xpath:seconds-from-dateTime called without a valid dateTime";
		}
	};
	
	# fn:timezone-from-dateTime
	$RDF::Query::functions{"http://www.w3.org/2005/xpath-functions#timezone-from-dateTime"}	= sub {
		my $query	= shift;
		my $node	= shift;
		unless (blessed($node) and $node->isa('RDF::Query::Node::Literal')) {
			throw RDF::Query::Error::TypeError -text => "xpath:timezone-from-dateTime called without a literal term";
		}
		my $dt		= $node->datetime;
		if ($dt) {
			my $tz		= $dt->time_zone;
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
				$duration	.= "${s}S" if ($s > 0);
				
				return RDF::Query::Node::Literal->new($duration);
			}
		}
		throw RDF::Query::Error::TypeError -text => "xpath:timezone-from-dateTime called without a valid dateTime";
	};
	

}



1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
