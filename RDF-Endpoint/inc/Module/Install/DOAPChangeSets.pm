#line 1
package Module::Install::DOAPChangeSets;

use strict;
use 5.008;
use Module::Install::Base ();

use vars qw{$VERSION @ISA};
BEGIN {
        $VERSION = '0.03';
        @ISA     = 'Module::Install::Base';
}

sub write_doap_changes {
	my $self = shift;
	$self->admin->write_doap_changes(@_) if $self->is_admin;
}

sub write_doap_changes_xml {
	my $self = shift;
	$self->admin->write_doap_changes_xml(@_) if $self->is_admin;
}

1;

__END__
#line 81
