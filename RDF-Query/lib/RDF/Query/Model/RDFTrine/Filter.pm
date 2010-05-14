# RDF::Query::Model::RDFTrine::Filter
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Model::RDFTrine::Filter - Algebra class for Filter patterns

=head1 VERSION

This document describes RDF::Query::Model::RDFTrine::Filter version 2.202_01, released 30 January 2010.

=cut

package RDF::Query::Model::RDFTrine::Filter;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Log::Log4perl;
use Data::Dumper;
use Scalar::Util qw(blessed reftype refaddr);
use Carp qw(carp croak confess);

use RDF::Trine::Iterator qw(smap);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.202_01';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $filter )>

Returns a new Filter structure for execution by RDF::Trine.

=cut

sub new {
	my $class	= shift;
	my $orig	= shift;
	return bless( [ $orig ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return $self->[0]->construct_args( @_ );
}

=item C<< pattern >>

Returns the RDF::Trine::Pattern object.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0]->pattern( @_ );
}

=item C<< expr >>

Returns the RDF::Query::Expression object.

=cut

sub expr {
	my $self	= shift;
	return $self->[0]->expr( @_ );
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return $self->[0]->referenced_variables( @_ );
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->[0]->definite_variables( @_ );
}

=item C<< bind_variables ( \%bound ) >>

Returns a new algebra pattern with variables named in %bound replaced by their corresponding bound values.

=cut

sub bind_variables {
	my $self	= shift;
	my $class	= ref($self);
	my $bound	= shift;
	my $pattern	= $self->[0]->bind_variables( $bound );
	return $class->new( $pattern );
}

=item C<< as_sparql >>

=cut

sub as_sparql {
	my $self	= shift;
	return $self->[0]->as_sparql( @_ );
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
	my $l		= Log::Log4perl->get_logger("rdf.query.model.rdftrine");
	
	my $expr		= $self->expr;
	my $ggp			= $self->pattern;
	my ($bgp)		= $ggp->patterns;
	my @triples		= $bgp->triples;
	
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
	my $pattern	= RDF::Query::Algebra::Filter->new( $expr, $bgp->bind_variables( $bound ) );
	
	my @args;
	if (my $o = $args{ orderby }) {
		push( @args, orderby => [ map { $_->[1]->name => $_->[0] } grep { blessed($_->[1]) and $_->[1]->isa('RDF::Trine::Node::Variable') } @$o ] );
	}
	
	if ($l->is_debug) {
		$l->debug("unifying with store: " . refaddr( $model->_store ));
		$l->debug("filter pattern: " . Dumper($pattern));
		$l->debug("model contains:");
		$model->_debug;
	}
	
#	local($RDF::Trine::Store::DBI::debug)	= 1;
	return smap {
		my $bindings	= $_;
		return undef unless ($bindings);
		my %cast	= map {
						$_ => RDF::Query::Model::RDFTrine::_cast_to_local( $bindings->{ $_ } )
					} (keys %$bindings);
		$l->debug("[$modeldebug]" . Dumper(\%cast));
		return \%cast;
	} $model->get_pattern( $pattern, undef, @args );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
