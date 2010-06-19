#line 1
package Module::Install::Bugtracker;
use 5.006;
use strict;
use warnings;
use URI::Escape;
our $VERSION = '0.02';
use base qw(Module::Install::Base);

sub auto_set_bugtracker {
    my $self = shift;
    if ($self->name) {
        $self->bugtracker(
            sprintf 'http://rt.cpan.org/Public/Dist/Display.html?Name=%s',
            uri_escape($self->name),
        );
    } else {
        warn "can't set bugtracker if 'name' is not set\n";
    }
}
1;
__END__

#line 92

