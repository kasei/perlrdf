# RDF::Trine::Node::Resource
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Resource - RDF Node class for resources

=head1 VERSION

This document describes RDF::Trine::Node::Resource version 0.114_03

=cut

package RDF::Trine::Node::Resource;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use URI;
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.114_03';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $iri, [ $base ] )>

Returns a new Resource structure.

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	my $base	= shift;
	
	my @uni;
	my $count	= 0;
	
	my $buri;
	if (defined($base)) {
		$buri	= (blessed($base) and $base->isa('RDF::Trine::Node::Resource')) ? $base->uri_value : "$base";
		while ($buri =~ /([\x{00C0}-\x{EFFFF}]+)/) {
			my $text	= $1;
			push(@uni, $text);
			$buri		=~ s/$1/',____rq' . $count . '____,'/e;
			$count++;
		}
	}
	
	while ($uri =~ /([\x{00C0}-\x{EFFFF}]+)/) {
		my $text	= $1;
		push(@uni, $text);
		$uri		=~ s/$1/',____rq' . $count . '____,'/e;
		$count++;
	}
	
	if (defined($base)) {
		### We have to work around the URI module not accepting IRIs. If there's
		### Unicode in the IRI, pull it out, leaving behind a breadcrumb. Turn
		### the URI into an absolute URI, and then replace the breadcrumbs with
		### the Unicode.
		
		my $abs			= URI->new_abs( $uri, $buri );
		$uri			= $abs->as_string;
	}

	while ($uri =~ /,____rq(\d+)____,/) {
		my $num	= $1;
		my $i	= index($uri, ",____rq${num}____,");
		my $len	= 12 + length($num);
		substr($uri, $i, $len)	= shift(@uni);
	}
	
	return bless( [ 'URI', $uri ], $class );
}

=item C<< uri_value >>

Returns the URI/IRI value of this resource.

=cut

sub uri_value {
	my $self	= shift;
	return $self->[1];
}

=item C<< uri ( $uri ) >>

Returns the URI value of this resource, optionally updating the URI.

=cut

sub uri {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this resource.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $uri		= $self->uri_value;
	
	my $ns		= $context->{namespaces} || {};
	my %ns		= %$ns;
	foreach my $k (keys %ns) {
		my $v	= $ns{ $k };
		if (index($uri, $v) == 0) {
			my $qname	= join(':', $k, substr($uri, length($v)));
			return $qname;
		}
	}
	
	my $string	= $uri;
	my $escaped	= $self->_unicode_escape( $string );
	return '<' . $escaped . '>';
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return '<' . $self->uri_value . '>';
}

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	my $self	= shift;
	my $context	= shift;
	my $uri		= $self->uri_value;
	
	my $string	= $uri;
	$string	=~ s/\\/\\\\/g;
	my $escaped	= $self->_unicode_escape( $string );
	$escaped	=~ s/"/\\"/g;
	$escaped	=~ s/\n/\\n/g;
	$escaped	=~ s/\r/\\r/g;
	$escaped	=~ s/\t/\\t/g;
	return '<' . $escaped . '>';
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'URI';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node::Resource'));
	return ($self->uri_value eq $node->uri_value);
}

# called to compare two nodes of the same type
sub _compare {
	my $a	= shift;
	my $b	= shift;
	return ($a->uri_value cmp $b->uri_value);
}

=item C<< qname >>

If the IRI can be split into a namespace and local part for construction of a
QName, returns a list containing these two parts. Otherwise throws an exception.

=cut

sub qname {
	my $p		= shift;
	my $uri		= $p->uri_value;
	
	my $nameStartChar	= qr<([A-Za-z:_]|[\x{C0}-\x{D6}]|[\x{D8}-\x{D8}]|[\x{F8}-\x{F8}]|[\x{200C}-\x{200C}]|[\x{37F}-\x{1FFF}][\x{200C}-\x{200C}]|[\x{2070}-\x{2070}]|[\x{2C00}-\x{2C00}]|[\x{3001}-\x{3001}]|[\x{F900}-\x{F900}]|[\x{FDF0}-\x{FDF0}]|[\x{10000}-\x{10000}])>;
	my $nameChar		= qr<$nameStartChar|-|[.]|[0-9]|\x{B7}|[\x{0300}-\x{036F}]|[\x{203F}-\x{2040}]>;
	my $lnre			= qr<((${nameStartChar})($nameChar)*)>;
	if ($uri =~ m/${lnre}$/) {
		my $ln	= $1;
		my $ns	= substr($uri, 0, length($uri)-length($ln));
		return ($ns, $ln);
	} else {
		throw RDF::Trine::Error -text => "Can't turn IRI $uri into a QName.";
	}
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
