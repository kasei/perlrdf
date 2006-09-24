# RDF::Base::Node::Blank
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Node::Blank - RDF Blank class used for representing blank nodes.


=head1 VERSION

This document describes RDF::Base::Node::Blank version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Node::Blank;
    $blank = RDF::Base::Node::Blank->new( name => 'blank1' );

=head1 DESCRIPTION

RDF Blank nodes.

=cut

package RDF::Base::Node::Blank;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
use base qw(RDF::Base::Node);

# use Moose;
use Carp;
use Scalar::Util qw(blessed);
# extends 'RDF::Base::Node';

# has 'name'		=> ( is => 'rw', isa => 'Str', required => 1, default => sub { our $counter; sprintf("r%sr%s", time, $counter++) } );


# Module implementation here

=head1 METHODS

=over 4

=cut

=item C<< new ( name => $name ) >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	our $counter;
	my $name	= $args{ name } || sprintf("r%sr%s", time, $counter++);
	my $self	= bless( { name => $name }, $class );
}




=item C<< name >>

=cut

sub name {
	my $self	= shift;
	return $self->{ name };
}


=item C<< blank_identifier >>

Returns the identifying name of the blank node.

=cut

sub blank_identifier {
	my $self	= shift;
	return $self->name;
}




=item C<< is_blank >>

Returns true if the object is a valid blank node object.

=cut

sub is_blank {
	return 1;
}

=item C<< equal ( $node ) >>

Returns true if the object value is equal to that of the specified C<$node>.

=cut

sub equal {
	my ($self, $other) = @_;
	blessed($other) and $other->isa( 'RDF::Base::Node::Blank' ) and  $self->name eq $other->name;
}

=item C<< as_string >>

Returns a serialized representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return sprintf('(%s)', $self->name);
}

sub __from_RDF_Redland_Node {
	my $class	= shift;
	my $redland	= shift;
	my $id	= $redland->blank_identifier;
	return $class->new( name => $id );
}

1; # Magic true value required at end of module
__END__

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
  
RDF::Base::Node::Blank requires no configuration files or environment variables.


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


