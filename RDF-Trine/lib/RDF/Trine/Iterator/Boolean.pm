# RDF::Trine::Iterator::Boolean
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Boolean - Iterator class for boolean query results

=head1 VERSION

This document describes RDF::Trine::Iterator::Boolean version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Iterator::Boolean;
 
 my $iterator = RDF::Trine::Iterator::Boolean->new( [1] );
 my $bool = $iterator->get_boolean;
 if ($bool) {
 	print "Yes.\n";
 }

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Iterator> class.

=over 4

=cut

package RDF::Trine::Iterator::Boolean;

use strict;
use warnings;
no warnings 'redefine';
use JSON 2.0;

use base qw(RDF::Trine::Iterator);
our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

=item C<new ( \@results, %args )>

=item C<new ( \&results, %args )>

Returns a new SPARQL Result interator object. Results must be either
an reference to an array containing results or a CODE reference that
acts as an iterator, returning successive items when called, and
returning undef when the iterator is exhausted.

$type should be one of: bindings, boolean, graph.

=cut

sub new {
	my $class		= shift;
	my $stream		= shift || sub { undef };
	my %args		= @_;
	
	my $type		= 'boolean';
	return $class->SUPER::new( $stream, $type, [], %args );
}

sub _new {
	my $class	= shift;
	my $stream	= shift;
	my $type	= shift;
	my $names	= shift;
	my %args	= @_;
	return $class->new( $stream, %args );
}

=item C<is_boolean>

Returns true if the underlying result is a boolean value.

=cut

sub is_boolean {
	my $self			= shift;
	return 1;
}

=item C<as_string ( $max_size [, \$count] )>

Returns a string serialization of the stream data.

=cut

sub as_string {
	my $self	= shift;
	my $value	= $self->get_boolean ? 'true' : 'false';
	return $value;
}

=item C<as_xml ( $max_size )>

Returns an XML serialization of the stream data.

=cut

sub as_xml {
	my $self	= shift;
	my $value	= $self->get_boolean ? 'true' : 'false';
	my $xml	= <<"END";
<?xml version="1.0" encoding="utf-8"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
	<head></head>
	<boolean>${value}</boolean>
</sparql>
END
	return $xml;
}

=item C<< print_xml ( $fh, $max_size ) >>

Prints an XML serialization of the stream data to the filehandle $fh.

=cut

sub print_xml {
	my $self	= shift;
	my $fh		= shift;
	print {$fh} $self->as_xml;
}

=item C<as_json ( $max_size )>

Returns a JSON serialization of the stream data.

=cut

sub as_json {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $value	= $self->get_boolean ? JSON::true : JSON::false;
	my $data	= { head => { vars => [] }, boolean => $value };
	return to_json( $data );
}

=item C<< construct_args >>

Returns the arguments necessary to pass to the stream constructor _new
to re-create this stream (assuming the same closure as the first

=cut

sub construct_args {
	my $self	= shift;
	my $type	= $self->type;
	my $args	= $self->_args || {};
	return ($type, [], %{ $args });
}


1;

__END__

=back

=head1 DEPENDENCIES

L<JSON|JSON>

L<Scalar::Util|Scalar::Util>

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
