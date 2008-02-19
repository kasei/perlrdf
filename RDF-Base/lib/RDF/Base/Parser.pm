# RDF::Base::Parser
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Parser - Base class for RDF parser classes.


=head1 VERSION

This document describes RDF::Base::Parser version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Parser;

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=cut

package RDF::Base::Parser;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;
use Moose;

use Carp;

use Module::Pluggable	search_path	=> 'RDF::Base::Parser',
						sub_name	=> '_implementations',
						require		=> 1;


has 'name'				=> ( is => 'ro', isa => 'Str', predicate => 'has_name' );
has 'mimetype'			=> ( is => 'ro', isa => 'Str', predicate => 'has_mimetype' );
has 'uri'				=> ( is => 'ro', isa => 'Str', predicate => 'has_uri' );

=begin private

=item C<< BUILD >>

Moose BUILD method throws an exception if an attempt is made to create a literal
with both langauge and datatype.

=end private

=cut

sub BUILD {
	my ($self, $params)	= @_;

	my $count	= 0;
	$count++ if (exists($params->{'name'}));
	$count++ if (exists($params->{'mimetype'}));
	$count++ if (exists($params->{'uri'}));
	confess "Parser node cannot have more than one of: a name, a mimetype, or a uri" if ($count > 1);
	
	my ($key, $value);
	if (defined(my $name = $params->{'name'})) {
		($key, $value)	= (name => $name);
	} elsif (defined(my $type = $params->{'mimetype'})) {
		($key, $value)	= (mimetype=> $type);
	} elsif (defined(my $uri = $params->{'uri'})) {
		($key, $value)	= (uri => $uri);
	} else {
		($key, $value)	= (mimetype => 'application/rdf+xml');
	}

	foreach my $impl ($self->_implementations) {
		my $info	= $impl->parser_info;
		my $impl_value	= $info->{$key};
		if ((blessed($impl_value) and $impl_value->isa('Regexp')) ? ($value =~ m/$impl_value/) : ($value eq $info->{$key})) {
			$self->{'!implementation'}	= $impl->new;
			last;
		}
	}
	
	confess "Could not find appropriate parser with $key $value" unless (blessed($self->{'!implementation'}));
}


sub _impl {
	my $self	= shift;
	return $self->{'!implementation'};
}

# Module implementation here

=head1 METHODS

=over 4

=cut


=item new 

=item C<< new ( name => $name ) >>

=item C<< new ( mimetype => $mimetype ) >>

=item C<< new ( uri => $uri ) >>

Create a new RDF::Base::Parser object for a syntax parser named C<$name>,
with MIME Type C<$mimetype> and/or URI C<$uri>. If all are omitted, a parser
that provides MIME Type  application/rdf+xml will be requested.

=cut



=item C<< parse_as_stream ( $SOURCE_URI, $BASE_URI ) >>

Parse the syntax at the RDF::Redland::URI I<SOURCE_URI> with optional base
RDF::Redland::URI I<BASE_URI>.  If the base URI is given then the content is
parsed as if it was at the base URI rather than the source URI.

Returns an RDF::Redland::Stream of RDF::Redland::Statement objects or
undef on failure.

=cut

sub parse_as_stream ($$) {
	my $self	= shift;
	return $self->_impl->parse_as_stream( @_ );
}

=item C<< parse_into_model ( SOURCE_URI BASE_URI MODEL [HANDLER] ) >>

Parse the syntax at the RDF::Redland::URI I<SOURCE_URI> with optional base
RDF::Redland::URI I<BASE_URI> into RDF::Redland::Model I<MODEL>.  If the base URI is
given then the content is parsed as if it was at the base URI rather
than the source URI.

If the optional I<HANDLER> is given, it is a reference to a sub with the signature
  sub handler($$$$$$$$$) {
    my($code, $level, $facility, $message, $line, $column, $byte, $file, $uri)=@_;
    ...
  }
that receives errors in parsing.

=cut

sub parse_into_model ($$$;$) {
	my $self	= shift;
	return $self->_impl->parse_into_model( @_ );
}

=item C<< parse_string_as_stream ( STRING BASE_URI ) >>

Parse the syntax in I<STRING> with required base
RDF::Redland::URI I<BASE_URI>.

Returns an RDF::Redland::Stream of RDF::Redland::Statement objects or
undef on failure.

=cut

sub parse_string_as_stream ($$) {
	my $self	= shift;
	return $self->_impl->parse_string_as_stream( @_ );
}

=item C<< parse_string_into_model ( STRING BASE_URI MODEL [HANDLER] ) >>

Parse the syntax in I<STRING> with required base
RDF::Redland::URI I<BASE_URI> into RDF::Redfland::Model I<MODEL>.

If the optional I<HANDLER> is given, it is a reference to a sub with the signature
  sub handler($$$$$$$$$) {
    my($code, $level, $facility, $message, $line, $column, $byte, $file, $uri)=@_;
    ...
  }
that receives errors in parsing.

=cut

sub parse_string_into_model ($$$;$) {
	my $self	= shift;
	return $self->_impl->parse_string_into_model( @_ );
}













1; # Magic true value required at end of module
__END__

=begin private

=item C<< meta >>

=item C<< name >>

=item C<< has_mimetype >>

=item C<< has_name >>

=item C<< has_uri >>

=end private

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
  
RDF::Base::Parser requires no configuration files or environment variables.


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


