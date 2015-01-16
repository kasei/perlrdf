# RDF::Trine::Exporter::RDFPatch
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Exporter::RDFPatch - RDF-Patch Export

=head1 VERSION

This document describes RDF::Trine::Exporter::RDFPatch version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Exporter::RDFPatch;
 my $serializer	= RDF::Trine::Exporter::RDFPatch->new();

=head1 DESCRIPTION

The RDF::Trine::Exporter::RDFPatch class provides an API for serializing RDF
graphs to the RDF-Patch syntax.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Exporter::RDFPatch;

use strict;
use warnings;

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use List::Util qw(min);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

=item C<< new ( sink => $sink ) >>

Returns a new RDF-Patch exporter object.

=cut

sub new {
	my $class	= shift;
	my $ns		= {};

	my %args	= @_;
	if (exists $args{ namespaces }) {
		$ns	= $args{ namespaces };
	}
	
	my $sink	= $args{sink};
	
	my %rev;
	while (my ($ns, $uri) = each(%{ $ns })) {
		if (blessed($uri)) {
			$uri	= $uri->uri_value;
			if (blessed($uri)) {
				$uri	= $uri->uri_value;
			}
		}
		$rev{ $uri }	= $ns;
	}
	
	my $self = bless( {
		first	=> 1,
		ns		=> \%rev,
		last	=> [],
		sink	=> $sink,
	}, $class );
	return $self;
}

sub _sink {
	my $self	= shift;
	return $self->{sink};
}

=item C<< comment ( $c ) >>

Serializes a comment with the given string.

=cut

sub comment {
	my $self	= shift;
	my $c		= shift;
	$c			=~ s/\n/\n# /g;
	$self->_sink->emit("# $c\n");
}

=item C<< emit_operation ( $op, @operands ) >>

Serializes an operation identified by the character C<< $op >>, followed by C<< @operands >>
(separated by a single space) and a trailing DOT and newline.

=cut

sub emit_operation {
	my $self	= shift;
	my $op		= shift;
	my @args	= @_;
	$self->_sink->emit($op);
	foreach my $arg (@args) {
		$self->_sink->emit(' ');
		$self->_sink->emit($arg);
	}
	$self->_sink->emit(" .\n");
}

=item C<< add ( $st ) >>

Serializes an add/insert operation for the given statement object.

=cut

sub add {
	my $self	= shift;
	my $st	= shift;
	if ($self->{first}) {
		my $header	= $self->_header();
		$self->_sink->emit($header);
		$self->{first}	= 0;
	}
	my @list	= $self->terms_as_string_list( $st->nodes );
	$self->emit_operation( 'A', @list );
}

=item C<< delete ( $st ) >>

Serializes a delete operation for the given statement object.

=cut

sub delete {
	my $self	= shift;
	my $st	= shift;
	if ($self->{first}) {
		my $header	= $self->_header();
		$self->_sink->emit($header);
		$self->{first}	= 0;
	}
	my @list	= $self->terms_as_string_list( $st->nodes );
	$self->emit_operation( 'D', @list );
}

sub _header {
	my $self	= shift;
	my %ns		= reverse(%{ $self->{ns} });
	my @nskeys	= sort keys %ns;
	my $header	= '';
	if (@nskeys) {
		foreach my $ns (sort @nskeys) {
			my $uri	= $ns{ $ns };
			$header	.= "\@prefix $ns: <$uri> .\n";
		}
		$header	.= "\n";
	}
	return $header;
}

=item C<< statement_as_string ( $st ) >>

Returns a string with the supplied RDF::Trine::Statement object serialized as an RDF-Patch string.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	my @str_nodes	= $self->terms_as_string_list( @nodes );
	return join(' ', @str_nodes);
}

=item C<< terms_as_string_list ( @terms ) >>

Returns a list with each supplied term serialized as RDF-Patch strings.

=cut

sub terms_as_string_list {
	my $self	= shift;
	my @nodes	= @_;
	my @str_nodes	= map { $self->node_as_concise_string($_) } @nodes;
	if (1) {
		foreach my $i (0 .. min(scalar(@nodes), scalar(@{$self->{'last'}}))) {
			if (defined($self->{'last'}[$i]) and $nodes[$i]->equal( $self->{'last'}[$i])) {
				$str_nodes[$i]	= 'R';
			}
		}
		@{ $self->{'last'} }	= @nodes;
	}
	return @str_nodes;
}

=item C<< node_as_concise_string >>

Returns a string representation using RDF-Patch syntax shortcuts (e.g. PrefixNames).

=cut

sub node_as_concise_string {
	my $self	= shift;
	my $obj		= shift;
	if ($obj->isa('RDF::Trine::Node::Resource')) {
		my $value;
		try {
			my ($ns,$local)	= $obj->qname;
			if (blessed($self) and exists $self->{ns}{$ns}) {
				$value	= join(':', $self->{ns}{$ns}, $local);
				$self->{used_ns}{ $self->{ns}{$ns} }++;
			}
		} catch RDF::Trine::Error with {} otherwise {};
		if ($value) {
			return $value;
		}
	}
	return $obj->as_ntriples;
}

1;

__END__

=back

=head1 NOTES

As described in L<RDF::Trine::Node::Resource/as_ntriples>, serialization will
decode any L<punycode|http://www.ietf.org/rfc/rfc3492.txt> that is included in the IRI,
and serialize it using unicode codepoint escapes.

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://afs.github.io/rdf-patch/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
