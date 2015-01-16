# RDF::Trine::Exporter::CSV
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Exporter::CSV - Export RDF data to CSV

=head1 VERSION

This document describes RDF::Trine::Exporter::CSV version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Exporter::CSV;

=head1 DESCRIPTION

The RDF::Trine::Exporter::CSV class provides an API for serializing RDF data
to CSV strings and files.

=cut

package RDF::Trine::Exporter::CSV;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Text::CSV;
use Scalar::Util qw(blessed);
use RDF::Trine::Error qw(:try);

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

=head1 METHODS

=over 4

=item C<< new ( sep_char => $sep_char, quote => $bool ) >>

Returns a new RDF::Trine::Exporter::CSV object. If C<< $sep_char >> is provided,
it is used as the separator character in CSV serialization, otherwise a comma
(",") is used.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $sep		= $args{ sep_char } || ',';
	my $quote	= $args{ quote };
	my $csv		= Text::CSV->new ( { binary => 1, sep_char => $sep } );
	my $self	= bless( { %args, csv => $csv }, $class );
	return $self;
}

=item C<< serialize_iterator_to_file ( $file, $iterator ) >>

Serializes the bindings objects produced by C<< $iterator >>, printing the
results to the supplied filehandle C<<$fh>>.

=cut

sub serialize_iterator_to_file {
	my $self	= shift;
	my $file	= shift;
	my $iter	= shift;
	
	unless (blessed($iter) and ($iter->isa('RDF::Trine::Iterator::Bindings') or $iter->isa('RDF::Trine::Iterator::Graph'))) {
		my $type	= ref($iter);
		$type		=~ s/^RDF::Trine::Iterator:://;
		throw RDF::Trine::Error::MethodInvocationError -text => "CSV Exporter must be called with a Graph or VariableBindings iterator, not a $type iterator";
	}

	my $type	= ($iter->isa('RDF::Trine::Iterator::Bindings')) ? 'bindings' : 'graph';
	
	my $csv		= $self->{csv};
	my $quote	= $self->{quote};
	my @keys;
	while (my $row = $iter->next) {
		unless (scalar(@keys)) {
			@keys	= ($type eq 'bindings') ? (sort keys %$row) : qw(subject predicate object);
			$csv->print( $file, \@keys );
			print {$file} "\n";
		}
		my @data;
		foreach my $k (@keys) {
			my $v	= ($type eq 'bindings') ? $row->{$k} : $row->$k();
			if ($quote) {
				push(@data, $v->as_string);
			} elsif (blessed($v)) {
				if ($v->isa('RDF::Trine::Node::Resource')) {
					push(@data, $v->uri_value);
				} elsif ($v->isa('RDF::Trine::Node::Blank')) {
					push(@data, $v->blank_identifier);
				} elsif ($v->isa('RDF::Trine::Node::Literal')) {
					push(@data, $v->literal_value);
				}
			} else {
				push(@data, '');
			}
		}
		$csv->print( $file, \@data );
		print {$file} "\n";
	}
}

=item C<< serialize_iterator_to_string ( $iterator ) >>

Serializes the bindings objects produced by C<< $iterator >>, returning the
result as a string.

=cut

sub serialize_iterator_to_string {
	my $self	= shift;
	my $iter	= shift;
	my $string	= '';
	open( my $fh, '>', \$string );
	$self->serialize_iterator_to_file( $fh, $iter );
	close($fh);
	return $string;
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
