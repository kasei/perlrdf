# RDF::Query::Model::RDFTrine::BasicGraphPattern
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model::RDFTrine::BasicGraphPattern - Algebra class for BasicGraphPattern patterns

=cut

package RDF::Query::Model::RDFTrine::BasicGraphPattern;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Scalar::Util qw(blessed reftype refaddr);
use Carp qw(carp croak confess);

use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $bgp )>

Returns a new BasicGraphPattern structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my $orig	= shift;
	return bless( [ $pattern, $orig ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->pattern->triples);
}

=item C<< pattern >>

Returns the RDF::Trine::Pattern object.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0];
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return $self->pattern->referenced_variables;
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my $pattern	= $self->pattern->bind_variables( $bound );
	return $class->new( $pattern );
}

=item C<< as_sparql >>

=cut

sub as_sparql {
	my $self	= shift;
	return $self->[1]->as_sparql( @_ );
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	
	my $pattern		= $self->pattern;
	my @triples		= $pattern->triples;
	
	my $model;
	my $modeldebug;
	if (@triples and $triples[0]->isa('RDF::Trine::Statement::Quad')) {
		$modeldebug	= 'named';
		$model	= $bridge->_named_graphs_model;
	} else {
		$modeldebug	= 'default';
		$model	= $bridge->model;
	}
	
	# blank->var substitution
	foreach my $triple (@triples) {
		my @posmap	= ($triple->isa('RDF::Trine::Statement::Quad'))
					? qw(subject predicate object context)
					: qw(subject predicate object);
		foreach my $method (@posmap) {
			my $node	= $triple->$method();
			if ($node->isa('RDF::Trine::Node::Blank')) {
				my $var	= RDF::Trine::Node::Variable->new( '__' . $node->blank_identifier );
				$triple->$method( $var );
			}
		}
	}
	
	# BINDING has to happen after the blank->var substitution above, because
	# we might have a bound bnode.
	$pattern	= $pattern->bind_variables( $bound );
	
	my @args;
	if (my $o = $args{ orderby }) {
		push( @args, orderby => [ map { $_->[1]->name => $_->[0] } grep { blessed($_->[1]) and $_->[1]->isa('RDF::Trine::Node::Variable') } @$o ] );
	}
	
	if ($debug) {
		warn "unifying with store: " . refaddr( $model->_store ) . "\n";
		warn "bgp pattern: " . Dumper($pattern);
		warn "model contains:\n";
		$model->_debug;
	}
	return smap {
		my $bindings	= $_;
		return undef unless ($bindings);
		my %cast	= map {
						$_ => RDF::Query::Model::RDFTrine::_cast_to_local( $bindings->{ $_ } )
					} (keys %$bindings);
		warn "[$modeldebug]" . Dumper(\%cast) if ($debug);
		return \%cast;
	} $model->get_pattern( $pattern, undef, @args );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
