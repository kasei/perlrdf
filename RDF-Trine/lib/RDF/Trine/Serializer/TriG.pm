# RDF::Trine::Serializer::TriG
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Serializer::TriG - TriG Serializer

=head1 VERSION

This document describes RDF::Trine::Serializer::TriG version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Serializer::TriG;
 my $serializer	= RDF::Trine::Serializer::TriG->new();

=head1 DESCRIPTION

The RDF::Trine::Serializer::TriG class provides an API for serializing RDF
graphs to the TriG syntax.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer> class.

=over 4

=cut

package RDF::Trine::Serializer::TriG;

use strict;
use warnings;
use base qw(RDF::Trine::Serializer);

use URI;
use Carp;
use Encode;
use Data::Dumper;
use Scalar::Util qw(blessed refaddr reftype);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
	$RDF::Trine::Serializer::serializer_names{ 'trig' }	= __PACKAGE__;
# 	$RDF::Trine::Serializer::format_uris{ 'http://sw.deri.org/2008/07/n-quads/#n-quads' }	= __PACKAGE__;
# 	foreach my $type (qw(text/x-nquads)) {
# 		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
# 	}
}

######################################################################

=item C<< new >>

Returns a new TriG serializer object.

=cut

sub new {
	my $class	= shift;
	my $ns	= {};
	my $base_uri;

	my @args	= @_;
	my $ttl		= RDF::Trine::Serializer::Turtle->new(@args);
	if (@_) {
		if (scalar(@_) == 1 and reftype($_[0]) eq 'HASH') {
			$ns	= shift;
		} else {
			my %args	= @_;
			if (exists $args{ base }) {
				$base_uri   = $args{ base };
			}
			if (exists $args{ base_uri }) {
				$base_uri   = $args{ base_uri };
			}
			if (exists $args{ namespaces }) {
				$ns	= $args{ namespaces };
			}
		}
	}
	
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
		ns			=> \%rev,
		base_uri	=> $base_uri,
		ttl			=> $ttl,
	}, $class );
	
	return $self;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to TriG, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self	= shift;
	my $file	= shift;
	my $model	= shift;
	
	my %ns		= reverse(%{ $self->{ns} });
	my @nskeys	= sort keys %ns;
	if (@nskeys) {
		foreach my $ns (sort @nskeys) {
			my $uri	= $ns{ $ns };
			print $file "\@prefix $ns: <$uri> .\n";
		}
		print $file "\n";
	}
	
	my $s		= $self->{ttl};
	my $count	= $model->count_statements(undef, undef, undef, RDF::Trine::Node::Nil->new());
	if ($count) {
		my $iter	= $model->get_statements(undef, undef, undef, RDF::Trine::Node::Nil->new());
		print $file "{\n\t";
		my $ttl	= $s->serialize_iterator_to_string($iter);
		$ttl	=~ s/\n/\n\t/g;
		print {$file} $ttl;
		print $file "}\n\n";
	}
	
	my $graphs	= $model->get_graphs;
	while (my $g = $graphs->next) {
		my $iter	= $model->get_statements(undef, undef, undef, $g);
		print $file sprintf("%s {\n", $self->node_as_concise_string($g));
		my $ttl	= $s->serialize_iterator_to_string($iter);
		$ttl	=~ s/\n/\n\t/g;
		print $file $ttl;
		print $file "}\n\n";
	}
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to TriG, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self	= shift;
	my $model	= shift;
	my $iter	= $model->as_stream;
	my $data	= '';
	open(my $fh, '>:encoding(UTF-8)', \$data);
	$self->serialize_model_to_file($fh, $model);
	close($fh);
	return decode('UTF-8', $data);
}

=item C<< serialize_iterator_to_file ( $file, $iter ) >>

Serializes the iterator to TriG, printing the results to the supplied
filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $file	= shift;
	my $iter	= shift;
	
	my %ns		= reverse(%{ $self->{ns} });
	my @nskeys	= sort keys %ns;
	if (@nskeys) {
		foreach my $ns (sort @nskeys) {
			my $uri	= $ns{ $ns };
			print $file "\@prefix $ns: <$uri> .\n";
		}
		print $file "\n";
	}
	
	my $g;
	my $in_graph	= 0;
	my $s			= $self->{ttl};
	while (my $st = $iter->next) {
		my $new_graph	= $st->isa('RDF::Trine::Statement::Quad') ? $st->graph : RDF::Trine::Node::Nil->new();
		if (not($in_graph)) {
			$g	= $new_graph;
			if ($g->is_nil) {
				print $file "{\n"
			} else {
				print $file sprintf("%s {\n", $s->node_as_concise_string($g));
			}
		} elsif (not($g->equal($new_graph))) {
			$g	= $new_graph;
			print $file sprintf("}\n\n%s {\n", $s->node_as_concise_string($g));
		}
		$in_graph	= 1;
		
		print {$file} "\t" . $self->_statement_as_string( $st );
	}
	
	if ($in_graph) {
		print $file "}\n";
	}
}

=item C<< serialize_iterator_to_string ( $iter ) >>

Serializes the iterator to TriG, returning the result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $data	= '';
	open(my $fh, '>:encoding(UTF-8)', \$data);
	$self->serialize_iterator_to_file($fh, $iter);
	close($fh);
	return decode('UTF-8', $data);
}

sub _statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes;
	my $s			= $self->{ttl};
	@nodes	= ($st->nodes)[0..2];
	return join(' ', map { $s->node_as_concise_string($_) } @nodes) . " .\n";
}


=item C<< statement_as_string ( $st ) >>

Returns a string with the supplied RDF::Trine::Statement::Quad object serialized
as TriG, ending in a DOT and newline.

=cut

sub statement_as_string {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $st->nodes;
	return join(' ', map { $_->as_ntriples } @nodes[0..3]) . " .\n";
}


sub _node_concise_string {
	my $self	= shift;
	my $obj		= shift;
	if ($obj->is_literal and $obj->has_datatype) {
		my $dt	= $obj->literal_datatype;
		if ($dt =~ m<^http://www.w3.org/2001/XMLSchema#(integer|double|decimal)$> and $obj->is_canonical_lexical_form) {
			my $value	= $obj->literal_value;
			return $value;
		} else {
			my $dtr	= iri($dt);
			my $literal	= $obj->literal_value;
			my $qname;
			try {
				my ($ns,$local)	= $dtr->qname;
				if (blessed($self) and exists $self->{ns}{$ns}) {
					$qname	= join(':', $self->{ns}{$ns}, $local);
					$self->{used_ns}{ $self->{ns}{$ns} }++;
				}
			} catch RDF::Trine::Error with {};
			if ($qname) {
				my $escaped	= $obj->_unicode_escape( $literal );
				return qq["$escaped"^^$qname];
			}
		}
	} elsif ($obj->isa('RDF::Trine::Node::Resource')) {
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
	return;
}

=item C<< node_as_concise_string >>

Returns a string representation using common Turtle syntax shortcuts (e.g. for numeric literals).

=cut

sub node_as_concise_string {
	my $self	= shift;
	my $obj		= shift;
	my $str		= $self->_node_concise_string( $obj );
	if (defined($str)) {
		return $str;
	} else {
		return $obj->as_ntriples;
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://sw.deri.org/2008/07/n-quads/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
