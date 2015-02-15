=head1 NAME

RDF::Trine::Store::Redland - Redland-backed RDF store for RDF::Trine

=head1 VERSION

This document describes RDF::Trine::Store::Redland version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Store::Redland;

=head1 DESCRIPTION

RDF::Trine::Store::Redland provides an RDF::Trine::Store interface to the
Redland RDF store.


=cut

package RDF::Trine::Store::Redland;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Encode;
use Data::Dumper;
use RDF::Redland 1.00;
use Scalar::Util qw(refaddr reftype blessed);

use RDF::Trine::Error;

######################################################################

our $NIL_TAG;
our $VERSION;
BEGIN {
	$VERSION	= "1.012";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	$NIL_TAG	= 'tag:gwilliams@cpan.org,2010-01-01:RT:NIL';

	# XXX THE FOLLOWING IS TO KEEP DATA::DUMPER FROM CRAPPING OUT

	# insert these guys until we can get a fix into redland
	my $fk = sub { 'DUMMY' };
	my $nk = sub { undef };
	my $f  = sub { 'REDLAND PLEASE FIX YOUR API' };

	*_p_librdf_storage_s::FIRSTKEY = $fk;
	*_p_librdf_storage_s::NEXTKEY  = $nk;
	*_p_librdf_storage_s::FETCH	= $f;
	*_p_librdf_model_s::FIRSTKEY   = $fk;
	*_p_librdf_model_s::NEXTKEY	= $nk;
	*_p_librdf_model_s::FETCH	  = $f;

	# too bad these aren't implemented, since they could be useful
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $store ) >>

Returns a new storage object using the supplied RDF::Redland::Model object.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<Redland> for this backend.

The following keys may also be used:

=over

=item C<store_name>

The name of the storage factory (currently C<hashes>, C<mysql>,
C<memory>, C<file>, C<postgresql>, C<sqlite>, C<tstore>, C<uri> or
C<virtuoso>).

=item C<name>

The name of the storage.

=item C<options>

Any other options to be passed to L<RDF::Redland::Storage> as a hashref.

=back

=item C<new_with_object ( $redland_model )>

Initialize the store with a L<RDF::Redland::Model> object.


=cut

sub new {
	my $class	= shift;
	my $model	= shift;
	my $self	= bless({
		model	=> $model,
		bulk	=> 0,
	}, $class);
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	my ($store_name, $name, $opts)	= split(/;/, $config, 3);
	my $store	= RDF::Redland::Storage->new( $store_name, $name, $opts );
	my $model	= RDF::Redland::Model->new( $store, '' );
	return $class->new( $model );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift || { store_name => 'memory' };

	my $store	= RDF::Redland::Storage->new
		(@{$config}{qw(store_name name options)})
			or throw RDF::Trine::Error::DatabaseError
				-text => "Couldn't initialize Redland storage";
	my $model	= RDF::Redland::Model->new( $store, '' )
		or throw RDF::Trine::Error::DatabaseError
			-text => "Couldn't initialize Redland model";
	return $class->new( $model );
}

sub _new_with_object {
	my $class	= shift;
	my $obj		= shift;
	return unless (blessed($obj) and $obj->isa('RDF::Redland::Model'));
	return $class->new( $obj );
}

sub _config_meta {
	return {
		required_keys	=> [qw(store_name name options)],
		fields			=> {
			store_name	=> { description => 'Redland Storage Type', type => 'string' },
			name		=> { description => 'Storage Name', type => 'string' },
			options		=> { description => 'Options String', type => 'string' },
		},
	}
}

=item C<< temporary_store >>

Returns a temporary (empty) triple store.

=cut

sub temporary_store {
	my $class	= shift;
	return $class->_new_with_string( "hashes;test;new='yes',hash-type='memory',contexts='yes'" );
}

=item C<< get_statements ( $subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
	}
	
	my @rnodes;
	foreach my $pos (0 .. ($use_quad ? 3 : 2)) {
		my $n	= $nodes[ $pos ];
		if (blessed($n) and not($n->is_variable)) {
			push(@rnodes, _cast_to_redland($n));
		} else {
			push(@rnodes, undef);
		}
	}
	
	my $iter	= ($use_quad)
				? $self->_get_statements_quad( @rnodes )
				: $self->_get_statements_triple( @rnodes );
	return $iter;
}

sub _get_statements_triple {
	my $self	= shift;
	my @rnodes	= @_;
# 	warn '_get_statements_triple: ' . Dumper(\@rnodes);

	my $st		= RDF::Redland::Statement->new( @rnodes[0..2] );
	my $iter	= $self->_model->find_statements( $st );
	my %seen;
	my $sub		= sub {
		while (1) {
			return unless $iter;
			return if $iter->end;
			my $st	= $iter->current;
			if ($seen{ $st->as_string }++) {
				$iter->next;
				next;
			}
			my @nodes	= map { _cast_to_local($st->$_()) } qw(subject predicate object);
			$iter->next;
			return RDF::Trine::Statement->new( @nodes );
		}
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

sub _get_statements_quad {
	my $self	= shift;
	my @rnodes	= @_;
# 	warn '_get_statements_quad: ' . Dumper(\@rnodes);
	
	my $ctx		= $rnodes[3];
	my $ctx_local;
	if ($ctx) {
# 		warn "-> context " . $ctx->as_string;
		$ctx_local	= _cast_to_local( $ctx );
	}
	my $st		= RDF::Redland::Statement->new( @rnodes[0..2] );
	my $iter	= $self->_model->find_statements( $st, $ctx );
	my $nil		= RDF::Trine::Node::Nil->new();
	my $sub		= sub {
		return unless $iter;
		return if $iter->end;
		my $st	= $iter->current;
		my $c	= $iter->context;
		my @nodes	= map { _cast_to_local($st->$_()) } qw(subject predicate object);
		if ($ctx) {
			push(@nodes, $ctx_local);
		} elsif ($c) {
			push(@nodes, _cast_to_local($c));
		} else {
			push(@nodes, $nil);
		}
		$iter->next;
# 		warn Dumper(\@nodes);
		return RDF::Trine::Statement::Quad->new( @nodes );
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my @ctxs	= $self->_model->contexts();
 	return RDF::Trine::Iterator->new( sub { my $n = shift(@ctxs); return _cast_to_local($n) } );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;

	my $nil	= RDF::Trine::Node::Nil->new();
	if ($st->isa( 'RDF::Trine::Statement::Quad' )) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "add_statement cannot be called with both a quad and a context";
		}
	} else {
		my @nodes	= $st->nodes;
		if (blessed($context)) {
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $context );
		} else {
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $nil );
		}
	}

	my $model	= $self->_model;
	my @nodes	= $st->nodes;
	my @rnodes	= map { _cast_to_redland($_) } @nodes;
	my $rst		= RDF::Redland::Statement->new( @rnodes[0..2] );
	my $ret	 = $model->add_statement( $rst, $rnodes[3] );

	# redland needs to be synced
	$model->sync unless $self->{bulk};

	# for any code that was expecting this
	$ret;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	if ($st->isa( 'RDF::Trine::Statement::Quad' )) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "remove_statement cannot be called with both a quad and a context";
		}
	} else {
		my @nodes	= $st->nodes;
		if (blessed($context)) {
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $context );
		} else {
			my $nil	= RDF::Trine::Node::Nil->new();
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $nil );
		}
	}

	my @nodes	= $st->nodes;
	my @rnodes	= map { _cast_to_redland($_) } @nodes;
	my $model   = $self->_model;
	my $ret	 = $model->remove_statement( @rnodes );

	# redland needs to be synced
	$model->sync unless $self->{bulk};

	# for any code that was expecting this
	$ret;
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $iter	= $self->get_statements(@_);

	# temporarily store the value for bulk so we don't sync over and over
	my $bulk	= $self->{bulk};
	$self->{bulk} = 1;

	my $count = 0;
	while (my $st = $iter->next) {
		$self->remove_statement( $st );
		$count++;
	}

	# now put it back
	$self->{bulk} = $bulk;
	$self->_model->sync unless $bulk;

	# might as well return how many statements got deleted
	$count;
}

=item C<< count_statements ( $subject, $predicate, $object, $context ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and context. Any of the arguments may be undef to match any
value.

=cut

sub count_statements {
	my $self	= shift;
	my @nodes	= @_;
	if (scalar(@nodes) < 4) {
		# if it isn't 4, then make damn sure it's 3
		push @nodes, (undef) x (3 - @nodes);

# 		warn "restricting count_statements to triple semantics";
		my @rnodes	= map { _cast_to_redland($_) } @nodes[0..2];
		# force a 3-element list or you'll be sorry
		my $st		= RDF::Redland::Statement->new( @rnodes[0..2] );
		my $iter	= $self->_model->find_statements( $st );
		my $count	= 0;
		my %seen;
		while ($iter and my $st = $iter->current) {
			unless ($seen{ $st->as_string }++) {
				$count++;
			}
			$iter->next;
		}
		return $count;
	} else {
		my @rnodes	= map { _cast_to_redland($_) } @nodes;
		my $st		= RDF::Redland::Statement->new( @rnodes[0..2] );
		my $iter	= $self->_model->find_statements( $st, $rnodes[3] );
		my $count	= 0;
		while ($iter and my $st = $iter->current) {
			$count++;
			my $ctx	= $iter->context;
			$iter->next;
		}
		return $count;
	}
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->_model->size;
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	return;
}

sub _begin_bulk_ops {
	shift->{bulk} = 1;
}

sub _end_bulk_ops {
	my $self = shift;
	$self->{bulk} = 0;
	$self->_model->sync;
}

sub _model {
	my $self	= shift;
	return $self->{model};
}

sub _cast_to_redland {
	my $node	= shift;
	return unless (blessed($node));
	if ($node->isa('RDF::Trine::Statement')) {
		my @nodes	= map { _cast_to_redland( $_ ) } $node->nodes;
		return RDF::Redland::Statement->new( @nodes );
	} elsif ($node->isa('RDF::Trine::Node::Resource')) {
		return RDF::Redland::Node->new_from_uri( $node->uri_value );
	} elsif ($node->isa('RDF::Trine::Node::Blank')) {
		return RDF::Redland::Node->new_from_blank_identifier( $node->blank_identifier );
	} elsif ($node->isa('RDF::Trine::Node::Literal')) {
		my $lang	= $node->literal_value_language;
		my $dt		= $node->literal_datatype;
		my $value	= $node->literal_value;
		return RDF::Redland::Node->new_literal( "$value", $dt, $lang );
	} elsif ($node->isa('RDF::Trine::Node::Nil')) {
		return RDF::Redland::Node->new_from_uri( $NIL_TAG );
	} else {
		return;
	}
}

sub _cast_to_local {
	my $node	= shift;
	return unless (blessed($node));
	my $type	= $node->type;
	if ($type == $RDF::Redland::Node::Type_Resource) {
		my $uri	= $node->uri->as_string;
		if ($uri eq $NIL_TAG) {
			return RDF::Trine::Node::Nil->new();
		} else {
			return RDF::Trine::Node::Resource->new( $uri );
		}
	} elsif ($type == $RDF::Redland::Node::Type_Blank) {
		return RDF::Trine::Node::Blank->new( $node->blank_identifier );
	} elsif ($type == $RDF::Redland::Node::Type_Literal) {
		my $lang	= $node->literal_value_language;
		my $dturi	= $node->literal_datatype;
		my $dt		= ($dturi)
					? $dturi->as_string
					: undef;
		return RDF::Trine::Node::Literal->new( decode('utf8', $node->literal_value), $lang, $dt );
	} else {
		return;
	}
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
