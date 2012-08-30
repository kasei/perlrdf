# RDF::Trine::Parser::NTriples
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::NTriples - N-Triples Parser

=head1 VERSION

This document describes RDF::Trine::Parser::NTriples version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'ntriples' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::NTriples;

use strict;
use warnings;
use utf8;

use base qw(RDF::Trine::Parser);

use RDF::Trine qw(literal);
use RDF::Trine::Statement::Triple;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.000';
	$RDF::Trine::Parser::parser_names{ 'ntriples' }	= __PACKAGE__;
	foreach my $ext (qw(nt)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'text/plain';
	foreach my $type (qw(text/plain)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
	$RDF::Trine::Parser::format_uris{ 'http://www.w3.org/ns/formats/N-Triples' }	= __PACKAGE__;
}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my $self = bless( {@_}, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>.
For each RDF statement parsed, will call C<< $model->add_statement( $statement ) >>.

=item C<< parse_file_into_model ( $base_uri, $fh, $model [, context => $context] ) >>

Parses all data read from the filehandle C<< $fh >>.
For each RDF statement parsed, will call C<< $model->add_statement( $statement ) >>.

=cut


=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;
	open( my $fh, '<:utf8', \$string );
	return $self->parse_file( $base, $fh, $handler );
}

=item C<< parse_node ( $string, $base ) >>

Returns the RDF::Trine::Node object corresponding to the node whose N-Triples
serialization is found at the beginning of C<< $string >>.

=cut

sub parse_node {
	my $self	= shift;
	my $string	= shift;
	my $uri		= shift;
	my $n		= $self->_eat_node( $uri, 0, $string );
	return $n;
}

=item C<< parse_file ( $base, $fh, \&handler ) >>

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;
	
	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		open( $fh, '<:utf8', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	while (<$fh>) {
		chomp( $_ );
		my $statement = $self->parse_line($_);
		$handler->($statement) if ref $statement;
	}
}

sub parse_line {
	my $self = shift;
	my $line = shift;
	$line =~ s/^[ \t]*(?:#.*)?//;
	return unless $line;

	my $subject = $self->_parse_subject($line);
	$line =~ s/^[ \t]+// or _error("No whitespace between subject and predicate");
	my $predicate = $self->_parse_predicate($line);
	$line =~ s/^[ \t]+// or _error("No whitespace between predicate and object");
	my $object = $self->_parse_object($line);
	$line =~ s/^[ \t]*\.// or _error("Missing dot");
	$line =~ /^[ \t]*$/ or _error("Invalid syntax after dot");

	RDF::Trine::Statement::Triple->new($subject, $predicate, $object);
}

sub _parse_subject {
	my $self = shift;
	# Try parsing subject as URI
	if ($_[0] =~ s/^<//) {
		$_[0] =~ /^[^> ]+/ or _error("Invalid URI");
		my $uri = substr($_[0], 0, $+[0], '');
		$self->_unescape_uri($uri);
		$_[0] =~ s/^>// or _error("Invalid URI");
		return RDF::Trine::Node::Resource->new($uri);
	}
	# Try parsing subject as blank node
	elsif ($_[0] =~ s/^_://) {
		$_[0] =~ /^[a-z][a-z0-9]*/i;
		my $name = substr($_[0], 0, $+[0], '');
    return RDF::Trine::Node::Blank->new($name);
	}
	# Subject must be invalid
	else {
		_error("Invalid subject");
	}
}

sub _parse_predicate {
	my $self = shift;
	# Try parsing predicate as URI
	if ($_[0] =~ s/^<//) {
		$_[0] =~ /^[^> ]+/ or _error("Invalid URI");
		my $uri = substr($_[0], 0, $+[0], '');
		$self->_unescape_uri($uri);
		$_[0] =~ s/^>// or _error("Invalid URI");
		return RDF::Trine::Node::Resource->new($uri);
	}
	# Predicate must be invalid
	else {
		_error("Invalid predicate");
	}
}

sub _parse_object {
	my $self = shift;
	# Try parsing object as URI
	if ($_[0] =~ s/^<//) {
		$_[0] =~ /^[^> ]+/ or _error("Invalid URI");
		my $uri = substr($_[0], 0, $+[0], '');
		$self->_unescape_uri($uri);
		$_[0] =~ s/^>// or _error("Invalid URI");
		return RDF::Trine::Node::Resource->new($uri);
	}
	# Try parsing object as blank node
	elsif ($_[0] =~ s/^_://) {
		$_[0] =~ /^[a-z][a-z0-9]*/i;
		my $name = substr($_[0], 0, $+[0], '');
    return RDF::Trine::Node::Blank->new($name);
	}
	# Try parsing object as string
	elsif ($_[0] =~ s/^"//) {
		my $value;
		# First, try to parse a string without escape sequences
		if ($_[0] =~ /^[^\\"]*(?=")/) {
			$value = substr($_[0], 0, $+[0], '');
		}
		# If that doesn't work, try to parse a string with escape sequences
		else {
			$_[0] =~ /^(?:[^\\"]|(?:\\.))*/;
			$value = substr($_[0], 0, $+[0], '');
			$self->_unescape_string($value);
		}
		$_[0] =~ s/^"// or _error("Invalid string");
		# Check if the object has a language code
		if ($_[0] =~ s/^@//) {
			$_[0] =~ /^[a-z]+(?:-[a-z0-9]+)*/i or _error("Invalid language code");
			my $lang = substr($_[0], 0, $+[0], '');
			return RDF::Trine::Node::Literal->new($value, $lang);
		}
		# Check if the object has a datatype
		elsif ($_[0] =~ s/^\^\^//) {
			$_[0] =~ s/^<// or _error("Invalid datatype");
			$_[0] =~ /^[^> ]+/ or _error("Invalid datatype");
			my $uri = substr($_[0], 0, $+[0], '');
			$self->_unescape_uri($uri);
			$_[0] =~ s/^>// or _error("Invalid datatype");
			# Check if the value should be canonicalized
			if ($self->{canonicalize}) {
				return literal($value, undef, $uri)->canonicalize;
			}
			else {
				return RDF::Trine::Node::Literal->new($value, undef, $uri);
			}
		}
		else {
			return RDF::Trine::Node::Literal->new($value);
		}
	}
	# Object must be invalid
	else {
		_error("Invalid object: $_[0]");
	}
}

sub _unescape_uri {
	$_[1] =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/eg;
	$_[1] =~ s/\\U([0-9A-Fa-f]{8})/chr(hex($1))/eg;
}

{
	my %escapes = (q[\\] => qq[\\], r => qq[\r], n  => qq[\n], t => qq[\t], q["] => qq["]);
	
	sub _unescape_string {
		$_[1] =~ s/\\([\\tnr"])/$escapes{$1}/eg;
		$_[1] =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/eg;
		$_[1] =~ s/\\U([0-9A-Fa-f]{8})/chr(hex($1))/eg;
	}
}

sub _error {
  throw RDF::Trine::Error::ParserError -text => shift;
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
