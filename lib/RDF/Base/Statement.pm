# RDF::Base::Statement
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Statement - Statement class for representing RDF triples.


=head1 VERSION

This document describes RDF::Base::Statement version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Statement;
    $st = RDF::Base::Statement->new( subject => $s, predicate => $p, object => $o );

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=cut

package RDF::Base::Statement;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;

use RDF::Base::Node;
use Scalar::Util qw(blessed);
use Params::Coerce qw(coerce);

# use Moose;
use Carp;

# has 'subject'	=> ( is => 'rw', isa => 'RDF::Base::Node', required => 1 );
# has 'predicate'	=> ( is => 'rw', isa => 'RDF::Base::Node', required => 1 );
# has 'object'	=> ( is => 'rw', isa => 'RDF::Base::Node', required => 1 );
# has 'context'	=> ( is => 'rw', isa => 'RDF::Base::Node', predicate => 'has_context' );

# Module implementation here

=head1 METHODS

=over 4

=cut

=item C<< new ( subject => $s, predicate => $p, object => $o [, context => $c] ) >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $subj	= $args{ subject };
	my $pred	= $args{ predicate };
	my $obj		= $args{ object };
	my $context	= $args{ context };
	Carp::confess unless ($subj and $pred and $obj);
	my $self	= bless( { subject => $subj, predicate => $pred, object => $obj, context => $context }, $class );
}


=item C<< subject >>

Returns the statement's subject node.

=cut

sub subject {
	my $self	= shift;
	return $self->{subject};
}

=item C<< predicate >>

Returns the statement's predicate node.

=cut

sub predicate {
	my $self	= shift;
	return $self->{predicate};
}

=item C<< object >>

Returns the statement's object node.

=cut

sub object {
	my $self	= shift;
	return $self->{object};
}

=item C<< context >>

Returns the statement's context node.

=cut

sub context {
	my $self	= shift;
	return $self->{context};
}

=item C<< has_context >>

Returns true if the statement has an associated context node.

=cut

sub has_context {
	my $self	= shift;
	return ref($self->{context}) ? 1 : 0;
}



=item C<< equal ( $statement ) >>

Returns true if the statement is equal to the specified C<$statement>.

=cut

sub equal {
	my ($self, $other) = @_;
	
	return 0 unless blessed($other) and $other->isa( 'RDF::Base::Statement' );
	return 0 unless $self->subject->equal( $other->subject );
	return 0 unless $self->predicate->equal( $other->predicate );
	return 0 unless $self->object->equal( $other->object );
	if ($self->has_context) {
		return 0 unless ($self->context->equal( $other->context ));
	} elsif ($other->has_context) {
		return 0;
	}
	return 1;
}

=item C<< parse ( $string ) >>

Parses the C<< $string >> and returns an object representing the serialized statement.

=cut

sub parse {
	my $self		= shift;
	my $line		= shift;
	chomp($line);
	my ($stuff, $context)		= $line =~ m(^{(.*)}\s*(.*)$);
	return unless $stuff;
	
	my (@triple)	= split(/,\s*/, $stuff, 3);
	return unless (@triple == 3);
	
	my @st;
	foreach (@triple) {
		my $node	= RDF::Base::Node->parse( $_ );
		return unless ($node);
		push(@st, $node);
	}
	
	my %data;
	@data{ qw(subject predicate object) }	= @st;
	
	if ($context) {
		my $c	= RDF::Base::Node->parse( $context );
		return unless ($c);
		$data{ context }	= $c;
	}
	
	my $st	= RDF::Base::Statement->new( %data );
	return $st;
}


=item C<< as_string >>

Returns a serialized representation of the statement.

=cut

sub as_string {
	my $self	= shift;
	return sprintf('{%s, %s, %s} %s', map { blessed($self->$_()) ? $self->$_()->as_string : '' } qw(subject predicate object context));
}

sub __from_RDF_Redland_Statement {
	my $class	= shift;
	my $redland	= shift;
	
#	my $str			= $redland->as_string;
#	warn $str;
#	my $statement	= RDF::Base::Statement->parse( $str );
	my %args;
	foreach my $method (qw(subject predicate object)) {
		my $node	= $redland->$method();
		if (defined($node)) {
			my $type	= $node->type;
			if ($type == $RDF::Redland::Node::Type_Resource) {
				$node	= coerce( 'RDF::Base::Node::Resource', $node );
			} elsif ($type == $RDF::Redland::Node::Type_Literal) {
				$node	= coerce( 'RDF::Base::Node::Literal', $node );
			} elsif ($type == $RDF::Redland::Node::Type_Blank) {
				$node	= coerce( 'RDF::Base::Node::Blank', $node );
			} else {
				die;
			}
		}
		$args{ $method }	= $node;
	}
	
	my $statement	= $class->new( %args );
}

1; # Magic true value required at end of module
__END__

=for private

=item C<< meta >>

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
RDF::Base::Statement requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


