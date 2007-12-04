# RDF::SPARQLResults::Boolean
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::SPARQLResults::Boolean - Stream (iterator) class for boolean query results.

=head1 SYNOPSIS

    use RDF::SPARQLResults;
    my $query	= RDF::Query->new( '...query...' );
    my $stream	= $query->execute();
    while (my $row = $stream->next) {
    	my @vars	= @$row;
    	# do something with @vars
    }

=head1 METHODS

=over 4

=cut

package RDF::SPARQLResults::Boolean;

use strict;
use warnings;
use JSON;

use base qw(RDF::SPARQLResults);
our ($REVISION, $VERSION, $debug);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$REVISION	= do { my $REV = (qw$Revision: 293 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= '1.000';
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

=item C<as_xml ( $max_size )>

Returns an XML serialization of the stream data.

=cut

sub as_xml {
	my $self			= shift;
	my $value	= $self->get_boolean ? 'true' : 'false';
	my $xml	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2001/sw/DataAccess/rf1/result2">
<head></head>
<results>
	<boolean>${value}</boolean>
</results>
</sparql>
END
	return $xml;
}

=item C<as_json ( $max_size )>

Returns a JSON serialization of the stream data.

=cut

sub as_json {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $value	= $self->get_boolean ? JSON::True : JSON::False;
	my $data	= { head => { vars => [] }, boolean => $value };
	return objToJson( $data );
}


1;

__END__

=back

=head1 DEPENDENCIES

L<JSON|JSON>

L<Scalar::Util|Scalar::Util>


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


