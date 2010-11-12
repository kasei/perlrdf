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
}

1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
