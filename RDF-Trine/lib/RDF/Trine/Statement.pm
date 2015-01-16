# RDF::Trine::Statement
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Statement - Class for triples and triple patterns

=head1 VERSION

This document describes RDF::Trine::Statement version 1.012

=cut

package RDF::Trine::Statement;

use strict;
use warnings;
no warnings 'redefine';

use Data::Dumper;
use Log::Log4perl;
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);
use RDF::Trine::Iterator qw(smap sgrep swatch);
use URI::Escape qw(uri_unescape);
use Encode;

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $s, $p, $o )>

Returns a new Triple structure.

=cut

sub new {
	my $class	= shift;
	my @nodes	= @_;
	unless (scalar(@nodes) == 3) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Triple constructor must have three node arguments";
	}
	my @names	= qw(subject predicate object);
	foreach my $i (0 .. 2) {
		unless (defined($nodes[ $i ])) {
			$nodes[ $i ]	= RDF::Trine::Node::Variable->new($names[ $i ]);
		}
	}
	
	return bless( [ @nodes ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->nodes);
}

=item C<< nodes >>

Returns the subject, predicate and object of the triple pattern.

=cut

sub nodes {
	my $self	= shift;
	return @$self;
}

=item C<< node_names >>

Returns the method names for accessing the nodes of this statement.

=cut

sub node_names {
	return qw(subject predicate object);
}

=item C<< subject >>

Returns the subject node of the triple pattern.

=cut

sub subject {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< predicate >>

Returns the predicate node of the triple pattern.

=cut

sub predicate {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< object >>

Returns the object node of the triple pattern.

=cut

sub object {
	my $self	= shift;
	if (@_) {
		$self->[2]	= shift;
	}
	return $self->[2];
}

=item C<< as_string >>

Returns the statement in a string form.

=cut

sub as_string {
	my $self	= shift;
	return $self->sse;
}

=item C<< has_blanks >>

Returns true if any of the nodes in this statement are blank nodes.

=cut

sub has_blanks {
	my $self	= shift;
	foreach my $node ($self->nodes) {
		return 1 if $node->isa('RDF::Trine::Node::Blank');
	}
	return 0;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	return sprintf(
		'(triple %s %s %s)',
		$self->subject->sse( $context ),
		$self->predicate->sse( $context ),
		$self->object->sse( $context ),
	);
}

=item C<< from_sse ( $string, $context ) >>

Parses the supplied SSE-encoded string and returns a RDF::Trine::Statement object.

=cut

sub from_sse {
	my $class	= shift;
	my $context	= $_[1];
	$_			= $_[0];
	if (m/^[(]triple/) {
		s/^[(]triple\s+//;
		my @nodes;
		push(@nodes, RDF::Trine::Node->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node->from_sse( $_, $context ));
		if (m/^\s*[)]/) {
			s/^\s*[)]//;
			return RDF::Trine::Statement->new( @nodes );
		} else {
			throw RDF::Trine::Error -text => "Cannot parse end-of-triple from SSE string: >>$_<<";
		}
	} else {
		throw RDF::Trine::Error -text => "Cannot parse triple from SSE string: >>$_<<";
	}
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'TRIPLE';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return RDF::Trine::_uniq(map { $_->name } grep { $_->isa('RDF::Trine::Node::Variable') } $self->nodes);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->referenced_variables;
}

=item C<< clone >>

=cut

sub clone {
	my $self	= shift;
	my $class	= ref($self);
	return $class->new( $self->nodes );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my @nodes	= $self->nodes;
	foreach my $i (0 .. 2) {
		my $n	= $nodes[ $i ];
		if ($n->isa('RDF::Trine::Node::Variable')) {
			my $name	= $n->name;
			if (my $value = $bound->{ $name }) {
				$nodes[ $i ]	= $value;
			}
		}
	}
	return $class->new( @nodes );
}

=item C<< subsumes ( $statement ) >>

Returns true if this statement will subsume the $statement when matched against
a triple store.

=cut

sub subsumes {
	my $self	= shift;
	my $st		= shift;
	my @nodes	= $self->nodes;
	my @match	= $st->nodes;
	
	my %bind;
	my $l		= Log::Log4perl->get_logger("rdf.trine.statement");
	foreach my $i (0..2) {
		my $m	= $match[ $i ];
		if ($nodes[$i]->isa('RDF::Trine::Node::Variable')) {
			my $name	= $nodes[$i]->name;
			if (exists( $bind{ $name } )) {
				$l->debug("variable $name has already been bound");
				if (not $bind{ $name }->equal( $m )) {
					$l->debug("-> and " . $bind{$name}->sse . " does not equal " . $m->sse);
					return 0;
				}
			} else {
				$bind{ $name }	= $m;
			}
		} else {
			return 0 unless ($nodes[$i]->equal( $m ));
		}
	}
	return 1;
}


=item C<< from_redland ( $statement ) >>

Given a RDF::Redland::Statement object, returns a perl-native
RDF::Trine::Statement object.

=cut

sub from_redland {
	my $self	= shift;
	my $rstmt	= shift;
	my $rs		= $rstmt->subject;
	my $rp		= $rstmt->predicate;
	my $ro		= $rstmt->object;
	
	my $cast	= sub {
		my $node	= shift;
		my $type	= $node->type;
		if ($type == $RDF::Redland::Node::Type_Resource) {
			my $uri	= $node->uri->as_string;
			if ($uri =~ /%/) {
				# Redland's parser doesn't properly unescape percent-encoded RDF URI References
				$uri	= decode_utf8(uri_unescape(encode_utf8($uri)));
			}
			return RDF::Trine::Node::Resource->new( $uri );
		} elsif ($type == $RDF::Redland::Node::Type_Blank) {
			return RDF::Trine::Node::Blank->new( $node->blank_identifier );
		} elsif ($type == $RDF::Redland::Node::Type_Literal) {
			my $lang	= $node->literal_value_language;
			my $dturi	= $node->literal_datatype;
			my $dt		= ($dturi)
						? $dturi->as_string
						: undef;
			return RDF::Trine::Node::Literal->new( $node->literal_value, $lang, $dt );
		} else {
			croak 'Unknown node type in statement conversion';
		}
	};
	
	my @nodes;
	foreach my $n ($rs, $rp, $ro) {
		push(@nodes, $cast->( $n ));
	}
	my $st	= $self->new( @nodes );
	return $st;
}

=item C<< rdf_compatible >>

Returns true if and only if the statement can be expressed in RDF. That is,
the subject of the statement must be a resource or blank node; the predicate
must be a resource; and the object must be a resource, blank node or literal.

RDF::Trine::Statement does allow statements to be created which cannot be
expressed in RDF - for instance, statements including variables.

=cut

sub rdf_compatible {
	my $self	= shift;

	return
		unless $self->subject->is_resource
		||     $self->subject->is_blank;
	
	return
		unless $self->predicate->is_resource;
	
	return
		unless $self->object->is_resource
		||     $self->object->is_blank
		||     $self->object->is_literal;
	
	return $self;
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
