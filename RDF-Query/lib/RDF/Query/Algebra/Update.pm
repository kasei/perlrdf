# RDF::Query::Algebra::Update
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Update - Algebra class for UPDATE operations

=head1 VERSION

This document describes RDF::Query::Algebra::Update version 2.910.

=cut

package RDF::Query::Algebra::Update;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(refaddr);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype refaddr);
use Time::HiRes qw(gettimeofday tv_interval);
use RDF::Trine::Iterator qw(smap sgrep swatch);

######################################################################

our ($VERSION);
my %TRIPLE_LABELS;
my @node_methods	= qw(subject predicate object);
BEGIN {
	$VERSION	= '2.910';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Algebra> class.

=over 4

=cut

=item C<new ( $delete_template, $insert_template, $pattern, \%dataset, $data_only_flag )>

Returns a new UPDATE structure.

=cut

sub new {
	my $class	= shift;
	my $delete	= shift;
	my $insert	= shift;
	my $pat		= shift;
	my $dataset	= shift;
	my $data	= shift;
	return bless([$delete, $insert, $pat, $dataset, $data], $class);
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->delete_template, $self->insert_template, $self->pattern);
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $string;
	my $delete	= $self->delete_template;
	my $insert	= $self->insert_template;
	my $dataset	= $self->dataset;
	my @ds_keys	= keys %{ $dataset || {} };
	if (@ds_keys) {
		my @defaults	= sort map { $_->sse } @{ $dataset->{default} || [] };
		my @named		= sort map { $_->sse } values %{ $dataset->{named} || {} };
		my @strings;
		push(@strings, (@defaults) ? '(defaults ' . join(' ', @defaults) . ')' : ());
		push(@strings, (@named) ? '(named ' . join(' ', @named) . ')' : ());
		
		my $ds_string	= '(dataset ' . join(' ', @strings) . ')';
		return sprintf(
			"(update (delete %s) (insert %s) (where %s) %s)",
			($delete ? $delete->sse( $context, $indent ) : ''),
			($insert ? $insert->sse( $context, $indent ) : ''),
			$self->pattern->sse( $context, $indent ),
			$ds_string,
		);
	} else {
		return sprintf(
			"(update (delete %s) (insert %s) (where %s))",
			($delete ? $delete->sse( $context, $indent ) : ''),
			($insert ? $insert->sse( $context, $indent ) : ''),
			$self->pattern->sse( $context, $indent ),
		);
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift || {};
	my $indent	= shift || '';
	my $delete	= $self->delete_template;
	my $insert	= $self->insert_template;
	my $ggp		= $self->pattern;
	
	my $dataset	= $self->dataset;
	my @ds_keys	= keys %{ $dataset || {} };
	my $ds_string	= '';
	if (@ds_keys) {
		my @defaults	= @{ $dataset->{default} || [] };
		my %named		= %{ $dataset->{named} || {} };
		my @strings;
		push(@strings, sprintf("USING <%s>", $_->uri_value)) foreach (@defaults);
		push(@strings, sprintf("USING NAMED <%s>", $named{$_}->uri_value)) foreach (keys %named);
		$ds_string	= join("\n${indent}", @strings);
	}
	
	if ($insert or $delete) {
		# TODO: $(delete|insert)->as_sparql here isn't properly serializing GRAPH blocks, because even though they contain Quad objects inside of BGPs, there's no containing NamedGraph object...
		if ($ds_string) {
			$ds_string	= "\n${indent}$ds_string";
		}
		
		if ($insert and $delete) {
			return sprintf(
				"DELETE {\n${indent}	%s\n${indent}}\n${indent}INSERT {\n${indent}	%s\n${indent}}\n${indent}%s\n${indent}WHERE %s",
				$delete->as_sparql( $context, "${indent}  " ),
				$insert->as_sparql( $context, "${indent}  " ),
				$ds_string,
				$ggp->as_sparql( { %$context, force_ggp_braces => 1 }, ${indent} ),
			);
		} elsif ($insert) {
			return sprintf(
				"INSERT {\n${indent}	%s\n${indent}}\n${indent}%s\n${indent}WHERE %s",
				$insert->as_sparql( $context, "${indent}  " ),
				$ds_string,
				$ggp->as_sparql( { %$context, force_ggp_braces => 1 }, ${indent} ),
			);
		} else {
			return sprintf(
				"DELETE {\n${indent}	%s\n${indent}}\n${indent}%s\n${indent}WHERE %s",
				$delete->as_sparql( $context, "${indent}  " ),
				$ds_string,
				$ggp->as_sparql( { %$context, force_ggp_braces => 1 }, ${indent} ),
			);
		}
	} else {
		my @pats	= $ggp->patterns;
		my $op		= ($delete) ? 'DELETE' : 'INSERT';
		my $temp	= ($delete) ? $delete : $insert;
		my $temps	= ($temp->isa('RDF::Query::Algebra::GroupGraphPattern'))
					? $temp->as_sparql( $context, "${indent}	" )
					: "{\n${indent}	" . $temp->as_sparql( $context, "${indent}	" ) . "\n${indent}}";
		if (scalar(@pats) == 0) {
			return sprintf(
				"${op} DATA %s",
				$temps
			);
		} else {
			if ($ds_string) {
				$ds_string	= "\n${indent}$ds_string\n${indent}";
			} else {
				$ds_string	= ' ';
			}
			return sprintf(
				"${op} %s%sWHERE %s",
				$temps,
				$ds_string,
				$ggp->as_sparql( { %$context, force_ggp_braces => 1 }, "${indent}" ),
			);
		}
	}
}

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	return;
}

=item C<< referenced_variables >>

=cut

sub referenced_variables {
	my $self	= shift;
	return;
}

=item C<< delete_template >>

=cut

sub delete_template {
	my $self	= shift;
	return $self->[0];
}

=item C<< insert_template >>

=cut

sub insert_template {
	my $self	= shift;
	return $self->[1];
}

=item C<< pattern >>

=cut

sub pattern {
	my $self	= shift;
	return $self->[2];
}

=item C<< dataset >>

=cut

sub dataset {
	my $self	= shift;
	return $self->[3];
}

=item C<< data_only >>

=cut

sub data_only {
	my $self	= shift;
	return $self->[4];
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	unless ($self->data_only) {
		# if self isn't an INSERT/DELETE DATA operation, then we need to check the template patterns, too
		if ($self->delete_template) {
			$self->delete_template->check_duplicate_blanks;
		}
		
		if ($self->insert_tempalte) {
			$self->insert_tempalte->check_duplicate_blanks;
		}
	}
	return $self->pattern->check_duplicate_blanks;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
