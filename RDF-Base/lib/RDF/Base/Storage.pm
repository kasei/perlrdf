# RDF::Base::Storage
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Storage - Base class for RDF storage classes.


=head1 VERSION

This document describes RDF::Base::Storage version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Storage;

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=cut

package RDF::Base::Storage;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;

use Module::Pluggable	search_path	=> 'RDF::Base::Storage',
						sub_name	=> 'backends',
						require		=> 1;
__PACKAGE__->backends();

use Carp;

require Exporter;
our @ISA 	= qw(Exporter);
our @EXPORT	= qw(supports);

# sub new;
# sub add_statement;
# sub exists_statement;
# sub count_statements;
# sub get_statements;

# Module implementation here

=head1 METHODS

=over 4

=cut




=item C<< supports ( $feature ) >>

Called from RDF::Base::Storage sub-classes, this method will set up the appropriate
class variables for declaring that the storage sub-class supports the
specified C<$feature>.

=cut

sub supports ($) {
	my $class		= shift;
	my $feature		= shift;
	my ($package)	= caller();
	no strict 'refs';
	
	${ "${package}::supports" }{ $feature }++;
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
  
RDF::Base::Storage requires no configuration files or environment variables.


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


=cut


-*- x-counterpart: ../../../t/storage.t; -*-
