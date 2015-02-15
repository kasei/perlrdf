=head1 NAME

RDF::Trine::Serializer::NTriples::Canonical - Canonical representation of an RDF model

=head1 VERSION

This document describes RDF::Trine::Serializer::NTriples::Canonical version 1.012

=head1 SYNOPSIS

  use RDF::Trine::Serializer::NTriples::Canonical;
  my $serializer = RDF::Trine::Serializer::NTriples->new( onfail=>'truncate' );
  $serializer->serialize_model_to_file(FH, $model);

=head1 DESCRIPTION

This module produces a canonical string representation of an RDF graph.
If the graph contains blank nodes, sometimes there is no canonical
representation that can be produced. The 'onfail' option allows you to
decide what is done in those circumstances:

=over 8

=item * truncate - drop problematic triples and only serialize a subgraph.

=item * append - append problematic triples to the end of graph. The result will be non-canonical. This is the default behaviour.

=item * space - As with 'append', but leave a blank line separating the canonical and non-canonical portions of the graph.

=item * die - cause a fatal error.

=back

Other than the 'onfail' option, this package has exactly the same
interface as L<RDF::Trine::Serializer::NTriples>, providing
C<serialize_model_to_file> and C<serialize_model_to_string> methods.

This package will be considerably slower than the non-canonicalising
serializer though, so should only be used for small to medium-sized
graphs, and only when you need canonicalisation (e.g. for side-by-side
comparison of two graphs to check they're isomorphic; or creating a
canonical representation for digital signing).

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Serializer::NTriples> class.

=over 4

=cut

package RDF::Trine::Serializer::NTriples::Canonical;

use 5.010;
use strict;
use warnings;

use Carp;
use RDF::Trine;
use base qw(RDF::Trine::Serializer::NTriples);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
	$RDF::Trine::Serializer::serializer_names{ 'ntriples-canonical' }	= __PACKAGE__;
# 	foreach my $type (qw(text/plain)) {
# 		$RDF::Trine::Serializer::media_types{ $type }	= __PACKAGE__;
# 	}
}

######################################################################

=item C<< new ( [ onfail => $rule ] ) >>

Returns a new Canonical N-Triples serializer object. If specified, the value of
the 'onfail' argument dictates the handling of blank nodes with no canonical
representation. The allowable rule values are 'truncate', 'append', 'space',
and 'die', and their respective behaviour is described in L</DESCRIPTION> above.

=cut

sub new {
	my $class	= shift;
	my %opts	= (onfail => '');
	
	while (@_) {
		my $field = lc shift;
		my $value = shift;
		$opts{$field} = $value;
	}
	
	return bless \%opts, $class;
}

=item C<< serialize_model_to_file ( $fh, $model ) >>

Serializes the C<$model> to canonical NTriples, printing the results to the
supplied filehandle C<<$fh>>.

=cut

sub serialize_model_to_file {
	my $self  = shift;
	my $file  = shift;
	my $model = shift;
	
	my $string = $self->serialize_model_to_string($model);
	print {$file} $string;
}

=item C<< serialize_model_to_string ( $model ) >>

Serializes the C<$model> to canonical NTriples, returning the result as a string.

=cut

sub serialize_model_to_string {
	my $self  = shift;
	my $model = shift;
	
	my $blankNodes = {};
	my @statements;
	
	my $stream = $model->as_stream;
	while (my $ST = $stream->next) {
		push @statements, { 'trine' => $ST };
		
		if ($ST->subject->isa('RDF::Trine::Node::Blank')) {
			$blankNodes->{ $ST->subject->blank_identifier }->{'trine'} = $ST->subject;
		}
		
		if ($ST->object->isa('RDF::Trine::Node::Blank')) {
			$blankNodes->{ $ST->object->blank_identifier }->{'trine'} = $ST->object;
		}
	}
	
	my %lexCounts;
	
	foreach my $st (@statements) {
		# Really need to canonicalise typed literals as per XSD.
		
		$st->{'lex'} = sprintf('%s %s %s',
			($st->{'trine'}->subject->isa('RDF::Trine::Node::Blank') ? '~' : $st->{'trine'}->subject->as_ntriples),
			$st->{'trine'}->predicate->as_ntriples,
			($st->{'trine'}->object->isa('RDF::Trine::Node::Blank') ? '~' : $st->{'trine'}->object->as_ntriples)
			);
		$lexCounts{ $st->{'lex'} }++;
	}

	my $blankNodeCount   = scalar keys %$blankNodes;
	my $blankNodeLength  = length "$blankNodeCount";
	my $blankNodePattern = '_:g%0'.$blankNodeLength.'d';
	my $hardNodePattern  = '_:h%0'.$blankNodeLength.'d';
	
	@statements = sort { $a->{'lex'} cmp $b->{'lex'} } @statements;
	
	my $genSymCounter = 1;
	
	foreach my $st (@statements) {
		next unless $lexCounts{ $st->{'lex'} } == 1;
		
		if ($st->{'trine'}->object->isa('RDF::Trine::Node::Blank')) {
			unless (defined $blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'}) {
				$blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'} =
					sprintf($blankNodePattern, $genSymCounter);
				$genSymCounter++;
			}
			my $b = $blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'};
			$st->{'lex'} =~ s/\~$/$b/;
		}
		
		if ($st->{'trine'}->subject->isa('RDF::Trine::Node::Blank')) {
			unless (defined $blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'}) {
				$blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'} =
					sprintf($blankNodePattern, $genSymCounter);
				$genSymCounter++;
			}
			my $b = $blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'};
			$st->{'lex'} =~ s/^\~/$b/;
		}
	}
	
	foreach my $st (@statements) {
		if ($st->{'lex'} =~ /\~$/) {
			if (defined $blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'}) {
				my $b = $blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'};
				$st->{'lex'} =~ s/\~$/$b/;
			}
		}
		
		if ($st->{'lex'} =~ /^\~/) {
			if (defined $blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'}) {
				my $b = $blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'};
				$st->{'lex'} =~ s/^\~/$b/;
			}
		}
	}
	
	@statements = sort { $a->{'lex'} cmp $b->{'lex'} } @statements;
	
	my @canonicalStatements;
	my @otherStatements;
	foreach my $st (@statements) {
		if ($st->{'lex'} =~ /(^\~)|(\~$)/) {
			if (lc $self->{'onfail'} eq 'die') {
				croak "Model could not be canonicalised";
			} elsif (lc $self->{'onfail'} eq 'truncate') {
				next;
			}
			
			if ($st->{'lex'} =~ /\~$/) {
				unless (defined $blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'}) {
					$blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'} =
						sprintf($hardNodePattern, $genSymCounter);
					$genSymCounter++;
				}
				my $b = $blankNodes->{ $st->{'trine'}->object->blank_identifier }->{'lex'};
				$st->{'lex'} =~ s/\~$/$b/;
			}

			if ($st->{'lex'} =~ /^\~/) {
				unless (defined $blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'}) {
					$blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'} =
						sprintf($hardNodePattern, $genSymCounter);
					$genSymCounter++;
				}
				my $b = $blankNodes->{ $st->{'trine'}->subject->blank_identifier }->{'lex'};
				$st->{'lex'} =~ s/^\~/$b/;
			}

			push @otherStatements, $st;
		} else {
			push @canonicalStatements, $st;
		}
	}
	
	my $rv = '';
	foreach my $st (@canonicalStatements) {
		$rv .= $st->{'lex'} . " .\r\n";
	}

	$rv .= "\r\n"
		if (defined($self->{'onfail'}) && (lc $self->{'onfail'} eq 'space'));
	
	foreach my $st (@otherStatements) {
		$rv .= $st->{'lex'} . " .\r\n";
	}

	return $rv;
}

1;
__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

I<Signing RDF Graphs>, Jeremey J Carroll,
Digital Media Systems Laboratory, HB Laboratories Bristol.
HPL-2003-142, 23 July 2003.
L<http://www.hpl.hp.com/techreports/2003/HPL-2003-142.pdf>.

L<RDF::Trine>, L<RDF::Trine::Serializer::NTriples>.

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster, E<lt>tobyink@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010 Toby Inkster

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
