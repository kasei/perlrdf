# RDF::SPARQLResults::Bindings
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::SPARQLResults::Bindings - Stream (iterator) class for bindings query results.

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

package RDF::SPARQLResults::Bindings;

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

=item C<new ( \@results, \@names, %args )>

=item C<new ( \&results, \@names, %args )>

Returns a new SPARQL Result interator object. Results must be either
an reference to an array containing results or a CODE reference that
acts as an iterator, returning successive items when called, and
returning undef when the iterator is exhausted.

$type should be one of: bindings, boolean, graph.

=cut

sub new {
	my $class		= shift;
	my $stream		= shift || sub { undef };
	my $names		= shift || [];
	my %args		= @_;
	
	my $type		= 'bindings';
	return $class->SUPER::new( $stream, $type, $names, %args );
}

=item C<< binding_value_by_name ( $name ) >>

Returns the binding of the named variable in the current result.

=cut

sub binding_value_by_name {
	my $self	= shift;
	my $name	= shift;
	my $names	= $self->{_names};
	foreach my $i (0 .. $#{ $names }) {
		if ($names->[$i] eq $name) {
			return $self->binding_value( $i );
		}
	}
	warn "No variable named '$name' is present in query results.\n";
}

=item C<< binding_value ( $i ) >>

Returns the binding of the $i-th variable in the current result.

=cut

sub binding_value {
	my $self	= shift;
	my $val		= shift;
	my $row		= ($self->open) ? $self->current : $self->next;
	return $row->[ $val ];
}


=item C<binding_values>

Returns a list of the binding values from the current result.

=cut

sub binding_values {
	my $self	= shift;
	my $row		= ($self->open) ? $self->current : $self->next;
	return @$row;
}


=item C<binding_names>

Returns a list of the binding names.

=cut

sub binding_names {
	my $self	= shift;
	my $names	= $self->{_names};
	return @$names;
}

=item C<binding_name ( $i )>

Returns the name of the $i-th result column.

=cut

sub binding_name {
	my $self	= shift;
	my $names	= $self->{_names};
	my $val		= shift;
	return $names->[ $val ];
}


=item C<bindings_count>

Returns the number of variable bindings in the current result.

=cut

sub bindings_count {
	my $self	= shift;
	my $names	= $self->{_names};
	my $row		= ($self->open) ? $self->current : $self->next;
	return scalar( @$names )if (scalar(@$names));
	return 0 unless ref($row);
	return scalar( @$row );
}

=item C<as_json ( $max_size )>

Returns a JSON serialization of the stream data.

=cut

sub as_json {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $width			= $self->bindings_count;
	my $bridge			= $self->_bridge;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $self->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my $count	= 0;
	my $parsed	= $bridge->parsed;
	my $order	= ref($parsed->{options}{orderby}) ? JSON::True : JSON::False;
	my $dist	= $parsed->{options}{distinct} ? JSON::True : JSON::False;
	
	my $data	= {
					head	=> { vars => \@variables },
					results	=> { ordered => $order, distinct => $dist },
				};
	my @bindings;
	while (!$self->finished) {
		my %row;
		for (my $i = 0; $i < $width; $i++) {
			my $name		= $self->binding_name($i);
			my $value		= $self->binding_value($i);
			if (my ($k, $v) = format_node_json($bridge, $value, $name)) {
				$row{ $k }		= $v;
			}
		}
		
		push(@{ $data->{results}{bindings} }, \%row);
		last if ($max_result_size and ++$count >= $max_result_size);
	} continue { $self->next_result }
	
	return objToJson( $data );
}

=item C<as_xml ( $max_size )>

Returns an XML serialization of the stream data.

=cut

sub as_xml {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $width			= $self->bindings_count;
	my $bridge			= $self->_bridge;
	
	my @variables;
	for (my $i=0; $i < $width; $i++) {
		my $name	= $self->binding_name($i);
		push(@variables, $name) if $name;
	}
	
	my $count	= 0;
	my $t	= join("\n\t", map { qq(<variable name="$_"/>) } @variables);
	my $xml	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2001/sw/DataAccess/rf1/result2">
<head>
	${t}
</head>
<results>
END
	while (!$self->finished) {
		my @row;
		$xml	.= "\t\t<result>\n";
		for (my $i = 0; $i < $width; $i++) {
			my $name		= $self->binding_name($i);
			my $value		= $self->binding_value($i);
			$xml	.= "\t\t\t" . $self->format_node_xml($bridge, $value, $name) . "\n";
		}
		$xml	.= "\t\t</result>\n";
		
		last if ($max_result_size and ++$count >= $max_result_size);
	} continue { $self->next_result }
	$xml	.= <<"EOT";
</results>
</sparql>
EOT
	return $xml;
}

=begin private

=item C<format_node_json ( $node, $name )>

Returns a string representation of C<$node> for use in a JSON serialization.

=end private

=cut

sub format_node_json ($$$) {
	my $bridge	= shift;
	return undef unless ($bridge);
	
	my $node	= shift;
	my $name	= shift;
	my $node_label;
	
	if(!defined $node) {
		return;
	} elsif ($bridge->is_resource($node)) {
		$node_label	= $bridge->uri_value( $node );
		return $name => { type => 'uri', value => $node_label };
	} elsif ($bridge->is_literal($node)) {
		$node_label	= $bridge->literal_value( $node );
		return $name => { type => 'literal', value => $node_label };
	} elsif ($bridge->is_blank($node)) {
		$node_label	= $bridge->blank_identifier( $node );
		return $name => { type => 'bnode', value => $node_label };
	} else {
		return;
	}
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


