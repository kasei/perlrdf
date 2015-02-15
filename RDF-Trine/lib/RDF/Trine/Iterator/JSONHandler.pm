# RDF::Trine::Iterator::JSONHandler
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::JSONHandler - JSON Handler for parsing SPARQL JSON Results format

=head1 VERSION

This document describes RDF::Trine::Iterator::JSONHandler version 1.012

=head1 STATUS

This module's API and functionality should be considered unstable.
In the future, this module may change in backwards-incompatible ways,
or be removed entirely. If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=head1 SYNOPSIS

 use RDF::Trine::Iterator::JSONHandler;
 my $handler = RDF::Trine::Iterator::JSONHandler->new();
 my $iter = $handler->parse( $json );

=head1 METHODS

=over 4

=cut

package RDF::Trine::Iterator::JSONHandler;

use strict;
use warnings;
use Scalar::Util qw(refaddr);

use JSON;
use Data::Dumper;
use RDF::Trine::VariableBindings;

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

=item C<< new >>

Returns a new JSON SPARQL Results parser object.

=cut

sub new {
	my $class	= shift;
	my %args	= %{ shift || {} };
	return bless(\%args, $class);
}

=item C<< parse ( $json ) >>

Returns a RDF::Trine::Iterator object containing the data from the supplied JSON
in JSON SPARQL Results format.

=cut

sub parse {
	my $self	= shift;
	my $json	= shift;
	my $data	= from_json($json, {utf8 => 1});
	my $head	= $data->{head};
	my $vars	= $head->{vars};
	my $res		= $data->{results};
	if (defined(my $bool = $data->{boolean})) {
		my $value	= ($bool) ? 1 : 0;
		return RDF::Trine::Iterator::Boolean->new([$value]);
	} elsif (my $binds = $res->{bindings}) {
		my @results;
		foreach my $b (@$binds) {
			my %data;
			foreach my $v (@$vars) {
				if (defined(my $value = $b->{ $v })) {
					my $type	= $value->{type};
					if ($type eq 'uri') {
						my $data	= $value->{value};
						$data{ $v }	= RDF::Trine::Node::Resource->new( $data );
					} elsif ($type eq 'bnode') {
						my $data	= $value->{value};
						$data{ $v }	= RDF::Trine::Node::Blank->new( $data );
					} elsif ($type eq 'literal') {
						my $data	= $value->{value};
						if (my $lang = $value->{'xml:lang'}) {
							$data{ $v }	= RDF::Trine::Node::Literal->new( $data, $lang );
						} else {
							$data{ $v }	= RDF::Trine::Node::Literal->new( $data );
						}
					} elsif ($type eq 'typed-literal') {
						my $data	= $value->{value};
						my $dt		= $value->{datatype};
						if ($self->{canonicalize}) {
							$data	= RDF::Trine::Node::Literal->canonicalize_literal_value( $data, $dt, 0 );
						}
						$data{ $v }	= RDF::Trine::Node::Literal->new( $data, undef, $dt );
					} else {
						warn Dumper($data, $b);
						throw RDF::Trine::Error -text => "Unknown node type $type during parsing of SPARQL JSON Results";
					}
				}
			}
			push(@results, RDF::Trine::VariableBindings->new( \%data ));
		}
		return RDF::Trine::Iterator::Bindings->new( \@results );
	}
	warn '*** ' . Dumper($data);
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
