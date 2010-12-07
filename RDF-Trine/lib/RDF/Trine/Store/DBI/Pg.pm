=head1 NAME

RDF::Trine::Store::DBI::Pg - PostgreSQL subclass of DBI store

=head1 VERSION

This document describes RDF::Trine::Store::DBI::Pg version 0.131


=head1 SYNOPSIS

    use RDF::Trine::Store::DBI::Pg;

=head1 DESCRIPTION

=cut

package RDF::Trine::Store::DBI::Pg;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store::DBI);

use Scalar::Util qw(blessed reftype refaddr);

our $VERSION;
BEGIN {
	$VERSION	= "0.131";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
}


sub _config_meta {
	return {
		required_keys	=> [qw(dsn username password name)],
		fields			=> {
			name		=> { description => 'Model Name', type => 'string' },
			dsn			=> { description => 'DSN', type => 'string', template => 'DBI:Pg:dbname=[%database%]' },
			database	=> { description => 'Database Name', type => 'string' },
			username	=> { description => 'Username', type => 'string' },
			password	=> { description => 'Password', type => 'password' },
			driver		=> { description => 'Driver', type => 'string', value => 'Pg' },
		},
	}
}

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store::DBI> class.

=over 4

=cut

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'DBI::Pg';
	return $proto->SUPER::new_with_config( $config );
}

sub _column_name {
	my $self	= shift;
	my @args	= @_;
	my $col		= lc(join('_', @args));
	return $col;
}



1; # Magic true value required at end of module
__END__

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-rdf-store-dbi@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
