# RDF::Query::Plan::ThresholdUnion
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Plan::ThresholdUnion - Executable query plan for unions.

=head1 METHODS

=over 4

=cut

package RDF::Query::Plan::ThresholdUnion;

use strict;
use warnings;
use base qw(RDF::Query::Plan);

use Scalar::Util qw(blessed);

use RDF::Query::ExecutionContext;
use RDF::Query::VariableBindings;

=item C<< new ( @plans ) >>

=cut

sub new {
	my $class	= shift;
	my @plans	= @_;
	my $self	= $class->SUPER::new( \@plans );
	my %vars;
	foreach my $plan (@plans) {
		foreach my $v ($plan->referenced_variables) {
			$vars{ $v }++;
		}
	}
	$self->[0]{referenced_variables}	= [ keys %vars ];
	return $self;
}

=item C<< execute ( $execution_context ) >>

=cut

sub execute ($) {
	my $self	= shift;
	my $context	= shift;
	if ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "ThresholdUnion plan can't be executed while already open";
	}
	
	my $iter	= $self->[1][0];
	$iter->execute( $context );
	
	if ($iter->state == $self->OPEN) {
		$self->[0]{iter}	= $iter;
		$self->[0]{idx}		= 0;
		$self->[0]{context}	= $context;
		$self->state( $self->OPEN );
	} else {
		warn "no iterator in execute()";
	}
	$self;
}

=item C<< next >>

=cut

sub next {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "next() cannot be called on an un-open ThresholdUnion";
	}
	my $iter	= $self->[0]{iter};
	my $row		= $iter->next;
	if ($row) {
		return $row;
	} else {
		return undef unless ($self->[0]{idx} < $#{ $self->[1] });
		$iter->close();
		my $index	= ++$self->[0]{idx};
		my $iter	= $self->[1][ $index ];
		$iter->execute( $self->[0]{context} );
		if ($iter->state == $self->OPEN) {
			$self->[0]{iter}	= $iter;
			return $self->next;
		} else {
			throw RDF::Query::Error::ExecutionError -text => "execute() on child [${index}] of UNION failed during next()";
		}
	}
}

=item C<< close >>

=cut

sub close {
	my $self	= shift;
	unless ($self->state == $self->OPEN) {
		throw RDF::Query::Error::ExecutionError -text => "close() cannot be called on an un-open ThresholdUnion";
	}
	$self->[0]{iter}->close();
	delete $self->[0]{iter};
	$self->SUPER::close();
}

=item C<< children >>

=cut

sub children {
	my $self	= shift;
	return @{ $self->[1] };
}

=item C<< optimistic >>

=cut

sub optimistic {
	my $self	= shift;
	return @{ $self->[1] }[ 0 .. $#{ $self->[1] } - 1 ];
}

=item C<< default >>

=cut

sub default {
	my $self	= shift;
	return $self->[1][ $#{ $self->[1] } ];
}

=item C<< distinct >>

Returns true if the pattern is guaranteed to return distinct results.

=cut

sub distinct {
	return 0;
}

=item C<< ordered >>

Returns true if the pattern is guaranteed to return ordered results.

=cut

sub ordered {
	return [];
}

=item C<< sse ( $context, $indent ) >>

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $more	= '    ';
	return sprintf("(threshold-union\n${indent}${more}%s\n${indent})", join("\n${indent}${more}", map { $_->sse( $context, "${indent}${more}" ) } $self->children));
}

=item C<< graph ( $g ) >>

=cut

sub graph {
	my $self	= shift;
	my $g		= shift;
	my (@children)	= map { $_->graph( $g ) } ($self->children);
	$g->add_node( "$self", label => "Threshold Union" . $self->graph_labels );
	$g->add_edge( "$self", $_ ) for (@children);
	return "$self";
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
