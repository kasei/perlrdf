# RDF::Trine::Iterator::Graph
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Graph - Iterator class for graph query results

=head1 VERSION

This document describes RDF::Trine::Iterator::Graph version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Iterator::Graph;
 
 my $iterator = RDF::Trine::Iterator::Graph->new( \&data );
 while (my $st = $iterator->next) {
   # $st is a RDF::Trine::Statement object
   print $st->as_string;
 }

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Iterator> class.

=over 4

=cut

package RDF::Trine::Iterator::Graph;

use strict;
use warnings;
no warnings 'redefine';

use JSON;
use List::Util qw(max);
use Scalar::Util qw(blessed);

use RDF::Trine::Iterator qw(sgrep);
use RDF::Trine::Iterator::Graph::Materialized;

use base qw(RDF::Trine::Iterator);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################


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
# 	Carp::confess unless (scalar(@_) % 2 == 0);
	my %args		= @_;
	
	my $type		= 'graph';
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

=item C<< as_bindings ( $s, $p, $o ) >>

Returns the iterator as a Bindings iterator, using the supplied triple nodes to
determine the variable bindings.

=cut

sub as_bindings {
	my $self	= shift;
	my @nodes	= @_;
	my @names	= qw(subject predicate object context);
	my %bindings;
	foreach my $i (0 .. $#names) {
		if (not($nodes[ $i ]) or not($nodes[ $i ]->isa('RDF::Trine::Node::Variable'))) {
			$nodes[ $i ]	= RDF::Trine::Node::Variable->new( $names[ $i ] );
		}
	}
	foreach my $i (0 .. $#nodes) {
		my $n	= $nodes[ $i ];
		$bindings{ $n->name }	= $names[ $i ];
	}
	my $context	= $nodes[ 3 ]->name;
	
	my $sub	= sub {
		my $statement	= $self->next;
		return unless ($statement);
		my %values		= map {
			my $method = $bindings{ $_ };
			$_ => $statement->$method()
		} grep { ($statement->isa('RDF::Trine::Statement::Quad')) ? 1 : ($_ ne $context) } (keys %bindings);
		return \%values;
	};
	return RDF::Trine::Iterator::Bindings->new( $sub, [ keys %bindings ] );
}

=item C<< materialize >>

Returns a materialized version of the current graph iterator.
The materialization process will leave this iterator empty. The materialized
iterator that is returned should be used for any future need for the iterator's
data.

=cut

sub materialize {
	my $self	= shift;
	my @data	= $self->get_all;
	my @args	= $self->construct_args;
	return $self->_mclass->_new( \@data, @args );
}

sub _mclass {
	return 'RDF::Trine::Iterator::Graph::Materialized';
}


=item C<< unique >>

Returns a Graph iterator that ensures the returned statements are unique. While
the underlying RDF graph is the same regardless of uniqueness, the iterator's
serialization methods assume the results are unique, and so use this method
before serialization.

Uniqueness is opt-in for efficiency concerns -- this method requires O(n) memory,
and so may have noticeable effects on large graphs.

=cut

sub unique {
	my $self	= shift;
	my %seen;
	no warnings 'uninitialized';
	my $stream	= sgrep( sub {
		my $s	= $_;
		my $str	= $s->as_string;
		not($seen{ $str }++)
	}, $self);
	return $stream;
}

=item C<is_graph>

Returns true if the underlying result is an RDF graph.

=cut

sub is_graph {
	my $self			= shift;
	return 1;
}

=item C<as_string ( $max_size [, \$count] )>

Returns a string table serialization of the stream data.

=cut

sub as_string {
	my $self			= shift;
	my $max_result_size	= shift || 0;
	my $rescount		= shift;
	my @names			= qw(subject predicate object);
	my $headers			= \@names;
	my @rows;
	my $count	= 0;
	while (my $row = $self->next) {
		push(@rows, [ map { blessed($_) ? $_->as_string : '' } map { $row->$_() } qw(subject predicate object) ]);
		last if ($max_result_size and ++$count >= $max_result_size);
	}
#	my $rows			= [ map { [ map { blessed($_) ? $_->as_string : '' } @{$_}{ @names } ] } @nodes ];
	if (ref($rescount)) {
		$$rescount	= scalar(@rows);
	}
	
	my @rule			= qw(- +);
	my @headers			= (\q"| ");
	push(@headers, map { $_ => \q" | " } @$headers);
	pop	@headers;
	push @headers => (\q" |");
	
	if ('ARRAY' eq ref $rows[0]) {
		if (@$headers == @{ $rows[0] }) {
			my $table = Text::Table->new(@headers);
			$table->rule(@rule);
			$table->body_rule(@rule);
			$table->load(@rows);
		
			return join('',
					$table->rule(@rule),
					$table->title,
					$table->rule(@rule),
					map({ $table->body($_) } 0 .. @rows),
					$table->rule(@rule)
				);
		} else {
			die("make_table() rows must be an AoA with rows being same size as headers");
		}
	} else {
		return '';
	}
}

=item C<as_xml ( $max_size )>

Returns an XML serialization of the stream data.

=cut

sub as_xml {
	my $self	= shift;
	my $max_result_size	= shift || 0;
	my $string	= '';
	open( my $fh, '>', \$string );
	$self->print_xml( $fh, $max_result_size );
	return $string;
}

=item C<< print_xml ( $fh, $max_size ) >>

Prints an XML serialization of the stream data to the filehandle $fh.

=cut

sub print_xml {
	my $self			= shift;
	my $fh				= shift;
	my $max_result_size	= shift || 0;
	my $graph			= $self->unique();
	
	my $count	= 0;
	print {$fh} <<"END";
<?xml version="1.0" encoding="utf-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
END
	while (my $stmt = $graph->next) {
		if ($max_result_size) {
			last if ($count++ >= $max_result_size);
		}
		my $p		= $stmt->predicate->uri_value;
		my $pos		= max( rindex( $p, '/' ), rindex( $p, '#' ) );
		my $ns		= substr($p,0,$pos+1);
		my $local	= substr($p, $pos+1);
		my $subject	= $stmt->subject;
		my $subjstr	= ($subject->is_resource)
					? 'rdf:about="' . $subject->uri_value . '"'
					: 'rdf:nodeID="' . $subject->blank_identifier . '"';
		my $object	= $stmt->object;
		
		print {$fh} qq[<rdf:Description $subjstr>\n];
		if ($object->is_resource) {
			my $uri	= $object->uri_value;
			print {$fh} qq[\t<${local} xmlns="${ns}" rdf:resource="$uri"/>\n];
		} elsif ($object->isa('RDF::Trine::Node::Blank')) {
			my $id	= $object->blank_identifier;
			print {$fh} qq[\t<${local} xmlns="${ns}" rdf:nodeID="$id"/>\n];
		} else {
			my $value	= $object->literal_value;
			# escape < and & and ' and " and >
			$value	=~ s/&/&amp;/g;
			$value	=~ s/'/&apos;/g;
			$value	=~ s/"/&quot;/g;
			$value	=~ s/</&lt;/g;
			$value	=~ s/>/&gt;/g;
			
			my $tag		= qq[${local} xmlns="${ns}"];
			if (defined($object->literal_value_language)) {
				my $lang	= $object->literal_value_language;
				$tag	.= qq[ xml:lang="${lang}"];
			} elsif (defined($object->literal_datatype)) {
				my $dt	= $object->literal_datatype;
				$tag	.= qq[ rdf:datatype="${dt}"];
			}
			print {$fh} qq[\t<${tag}>${value}</${local}>\n];
		}
		print {$fh} qq[</rdf:Description>\n];
	}
	print {$fh} "</rdf:RDF>\n";
}

=item C<as_json ( $max_size )>

Returns a JSON serialization of the stream data.

=cut

sub as_json {
	my $self			= shift;
	my $max_result_size	= shift;
	throw RDF::Trine::Error::SerializationError ( -text => 'There is no JSON serialization specified for graph query results' );
}

=item C<< as_hashref >>

Returns a hashref representing the model in an RDF/JSON-like manner.

See C<< as_hashref >> at L<RDF::Trine::Model> for full documentation of the
hashref format.

=cut

sub as_hashref {
	my $self = shift;
	my $index = {};
	while (my $statement = $self->next) {
		
		my $s = $statement->subject->isa('RDF::Trine::Node::Blank') ? 
			('_:'.$statement->subject->blank_identifier) :
			$statement->subject->uri ;
		my $p = $statement->predicate->uri ;
		push @{ $index->{$s}->{$p} }, $statement->object->as_hashref;
	}
	return $index;
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
