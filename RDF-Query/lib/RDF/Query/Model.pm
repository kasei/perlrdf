# RDF::Query::Model
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model - Model base class

=cut

package RDF::Query::Model;

use strict;
use warnings;

use RDF::Query::Error qw(:try);

use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 1;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=item C<parsed>

Returns the query parse tree.

=cut

sub parsed {
	my $self	= shift;
	return $self->{parsed};
}


=item C<< literal_as_array ( $literal ) >>

Returns a literal in ARRAY (model-neutral) form.

=cut

sub literal_as_array {
	my $self	= shift;
	my $literal	= shift;
	my $value	= $self->literal_value( $literal );
	my $lang	= $self->literal_value_language( $literal );
	my $dt		= $self->literal_datatype( $literal );
	return [ 'LITERAL', $value, $lang, ($dt) ? [ 'URI', $dt ] : undef ];
}

=item C<< as_node ( $node ) >>

Returns a RDF::Query::Node object for the given node.

=cut

sub as_node {
	my $self	= shift;
	my $node	= shift;
	return unless (blessed($node));
	return unless ($self->isa_node($node));
	if ($self->isa_resource( $node )) {
		return RDF::Query::Node::Resource->new( $self->uri_value( $node ) );
	} elsif ($self->isa_literal( $node )) {
		return RDF::Query::Node::Literal->new( $self->literal_value( $node ), $self->literal_value_language( $node ), $self->literal_datatype( $node ) );
	} elsif ($self->isa_blank( $node )) {
		return RDF::Query::Node::Blank->new( $self->blank_identifier( $node ) );
	}
}

=item C<< as_native ( $node, $base, \%namespaces ) >>

Returns bridge-native RDF node objects for the given node.

=cut

sub as_native {
	my $self	= shift;
	my $node	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	return unless (blessed($node) and $node->isa('RDF::Query::Node'));
	if ($node->isa('RDF::Query::Node::Resource')) {
		my $uri	= $node->uri_value;
		if (ref($uri) and reftype($uri) eq 'ARRAY') {
			$uri	= join('', $ns->{ $uri->[0] }, $uri->[1] );
		}
		if ($base) {
			### We have to work around the URI module not accepting IRIs. If there's
			### Unicode in the IRI, pull it out, leaving behind a breadcrumb. Turn
			### the URI into an absolute URI, and then replace the breadcrumbs with
			### the Unicode.
			my @uni;
			my $count	= 0;
			while ($uri =~ /([\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]+)/) {
				my $text	= $1;
				push(@uni, $text);
				$uri		=~ s/$1/',____' . $count . '____,'/e;
				$count++;
			}
			my $abs			= URI->new_abs( $uri, $base->uri_value );
			$uri			= $abs->as_string;
			while ($uri =~ /,____(\d+)____,/) {
				my $num	= $1;
				my $i	= index($uri, ",____${num}____,");
				my $len	= 10 + length($num);
				substr($uri, $i, $len)	= shift(@uni);
			}
		}
		return $self->new_resource( $uri );
	} elsif ($node->isa('RDF::Query::Node::Literal')) {
		my $dt	= $node->literal_datatype;
		if (ref($dt) and reftype($dt) eq 'ARRAY') {
			$dt	= join('', $ns->{ $dt->[0] }, $dt->[1] );
		}
		return $self->new_literal( $node->literal_value, $node->literal_value_language, $dt );
	} elsif ($node->isa('RDF::Query::Node::Blank')) {
		return $node;
#		return RDF::Query::Node::Variable->new();
#		return $self->new_blank( $node->blank_identifier );
	} else {
		# keep variables as they are
		return $node;
	}
}

# sub new;
# sub model;
# sub new_resource;
# sub new_literal;
# sub new_blank;
# sub new_statement;
# sub new_variable;
# sub isa_node;
# sub isa_resource;
# sub isa_literal;
# sub isa_blank;
# sub equals;
# sub as_string;
# sub literal_value;
# sub literal_datatype;
# sub literal_value_language;
# sub uri_value;
# sub blank_identifier;
# sub add_uri;
# sub add_string;
# sub statement_method_map;
# sub subject;
# sub predicate;
# sub object;
# sub get_statements;
# sub multi_get;
# sub add_statement;
# sub remove_statement;
# sub get_context;
# sub supports;
# sub node_count;
# sub model_as_stream;

=item C<count_statements ($subject, $predicate, $object)>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my @triple	= splice(@_, 0, 3);
	my $context	= shift;
	
	my @defs	= grep defined, @triple;
	my $model	= $self->{'model'};
	my $stream;
	
	my %args	= ( bridge => $self, named => 1 );
	
	my $iter	= $model->get_statements( @triple, $context );
	my $count	= 0;
	while (my $row = $iter->next) {
		$count++;
	}
	
	return $count;
}


=item C<< debug >>

Prints debugging information about the model (including all statements in the
model) to STDERR.

=cut

sub debug {
	my $self	= shift;
	my $stream	= $self->get_statements( map { $self->new_variable($_) } qw(s p o) );
	warn "------------------------------\n";
	while (my $st = $stream->next) {
		warn $self->as_string( $st );
	}
	warn "------------------------------\n";
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
