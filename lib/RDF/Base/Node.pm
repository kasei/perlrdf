# RDF::Base::Node
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Node - Base class for representing RDF nodes.


=head1 VERSION

This document describes RDF::Base::Node version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Node;

=head1 DESCRIPTION

The RDF::Base::Node class is used as a base class for RDF node types.

=cut

package RDF::Base::Node;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;

use Params::Coerce;
use Scalar::Util qw(blessed);

use Carp;
use URI;

# use Module::Pluggable	search_path	=> 'RDF::Base::Node',
# 						require		=> 1;
# __PACKAGE__->plugins();


# Module implementation here

=head1 METHODS

=over 4

=cut

=item C<< parse ( $string ) >>

Parses the C<< $string >> and returns an object representing the serialized node.

=cut

sub parse {
	my $self	= shift;
	$_			= shift;
	if (/^\[(.*)\]$/) {
		return RDF::Query::Node::Resource->new( $1 );
	} elsif (/^\((.*)\)$/) {
		return RDF::Query::Node::Blank->new( $1 );
	} elsif (/^(["'])([^"]*)\1/) {
		my $value	= $2;
		my $rest	= substr($_, length($2) + 2);
		if ($rest) {
			if ($rest =~ m/^@([A-Za-z_-]+)$/) {
				my $lang	= $1;
				return RDF::Query::Node::Literal->new( $value, $lang );
			} elsif ($rest =~ m/^\^\^<([^>]+)>$/) {
				my $dt	= $1;
				return RDF::Query::Node::Literal->new( $value, undef, $dt );
			} else {
				return;
			}
		} else {
			return RDF::Query::Node::Literal->new( $value );
		}
	} else {
		return;
	}
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
  
RDF::Base::Node requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 SEE ALSO

=over 4

=item * L<RDF::Base::Node::Resource>

=item * L<RDF::Base::Node::Literal>

=item * L<RDF::Base::Node::Blank>

=item * L<RDF::Base::Node::Variable>

=item * L<RDF::Base::Statement>

=back

=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


