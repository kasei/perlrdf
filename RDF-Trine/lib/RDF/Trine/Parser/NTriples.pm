# RDF::Trine::Parser::NTriples
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::NTriples - N-Triples Parser

=head1 VERSION

This document describes RDF::Trine::Parser::NTriples version 1.012

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

use Carp;
use Encode qw(decode);
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);

use RDF::Trine qw(literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
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

Parses the bytes in C<< $data >>.
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
	open( my $fh, '<:encoding(UTF-8)', \$string );
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
		open( $fh, '<:encoding(UTF-8)', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	my $lineno	= 0;
	no warnings 'uninitialized';
	while (defined(my $line = <$fh>)) {
LINE:
		($line, my @extra)	= split(/\r\n|\r|\n/, $line, 2);
		$lineno++;
		
		next unless (defined($line) and length($line));
		next unless ($line =~ /\S/);
		chomp($line);
		$line	=~ s/^\s*//;
		$line	=~ s/\s*$//;
		next if ($line =~ /^#/);
		
		my @nodes	= ();
		try {
			while (my $n = $self->_eat_node( $base, $lineno, $line )) {
				push(@nodes, $n);
				$line	=~ s/^\s*//;
			}
		};
		$line	=~ s/^\s//g;
		unless ($line eq '.') {
# 			Carp::cluck 'N-Triples parser failed: ' . Dumper(\@nodes, $line);
			throw RDF::Trine::Error::ParserError -text => "Missing expected '.' at line $lineno";
		}
		
		$self->_emit_statement( $handler, \@nodes, $lineno );
		if (@extra) {
			$line	= shift(@extra);
			goto LINE;
		}
	}
}

sub _emit_statement {
	my $self	= shift;
	my $handler	= shift;
	my $nodes	= shift;
	my $lineno	= shift;
	my $st;
	if (scalar(@$nodes) == 3) {
		if ($self->{canonicalize}) {
			if ($nodes->[2]->isa('RDF::Trine::Node::Literal') and $nodes->[2]->has_datatype) {
				my $value	= $nodes->[2]->literal_value;
				my $dt		= $nodes->[2]->literal_datatype;
				my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
				$nodes->[2]	= literal( $canon, undef, $dt );
			}
		}
		$st	= RDF::Trine::Statement->new( @$nodes );
# 	} elsif (scalar(@$nodes) == 4) {
# 		$st	= RDF::Trine::Statement::Quad->new( @$nodes );
	} else {
# 		warn Dumper($nodes);
		throw RDF::Trine::Error::ParserError -text => qq[Not valid N-Triples data at line $lineno];
	}
	$handler->( $st );
}

sub _eat_node {
	my $self	= shift;
	my $base	= shift;
	my $lineno	= shift;
	$_[0]	=~ s/^\s*//;
	return unless length($_[0]);
	my $char	= substr($_[0], 0, 1);
	return if ($char eq '.');
	
	if ($char eq '<') {
		my ($uri)	= $_[0] =~ m/^<([^>]*)>/;
		substr($_[0], 0, length($uri)+2)	= '';
		return RDF::Trine::Node::Resource->new( _unescape($uri, $lineno) );
	} elsif ($char eq '_') {
		my ($name)	= $_[0] =~ m/^_:([A-Za-z][A-Za-z0-9]*)/;
		substr($_[0], 0, length($name)+2)	= '';
		return RDF::Trine::Node::Blank->new( $name );
	} elsif ($char eq '"') {
		substr($_[0], 0, 1)	= '';
		my $value	= decode('utf8', '');
		while (length($_[0]) and substr($_[0], 0, 1) ne '"') {
			while ($_[0] =~ m/^([^"\\]+)/) {
				$value	.= $1;
				substr($_[0],0,length($1))	= '';
			}
			if (substr($_[0],0,1) eq '\\') {
				while ($_[0] =~ m/^\\(.)/) {
					if ($1 eq 't') {
						$value	.= "\t";
						substr($_[0],0,2)	= '';
					} elsif ($1 eq 'r') {
						$value	.= "\r";
						substr($_[0],0,2)	= '';
					} elsif ($1 eq 'n') {
						$value	.= "\n";
						substr($_[0],0,2)	= '';
					} elsif ($1 eq '"') {
						$value	.= '"';
						substr($_[0],0,2)	= '';
					} elsif ($1 eq '\\') {
						$value	.= "\\";
						substr($_[0],0,2)	= '';
					} elsif ($1 eq 'u') {
						$_[0] =~ m/^\\u([0-9A-Fa-f]{4})/ or throw RDF::Trine::Error::ParserError -text => qq[Bad N-Triples \\u escape at line $lineno, near "$_[0]"];
						$value	.= chr(oct('0x' . $1));
						substr($_[0],0,6)	= '';
					} elsif ($1 eq 'U') {
						$_[0] =~ m/^\\U([0-9A-Fa-f]{8})/ or throw RDF::Trine::Error::ParserError -text => qq[Bad N-Triples \\U escape at line $lineno, near "$_[0]"];
						$value	.= chr(oct('0x' . $1));
						substr($_[0],0,10)	= '';
					} else {
						throw RDF::Trine::Error::ParserError -text => qq[Not valid N-Triples escape character '\\$1' at line $lineno, near "$_[0]"];
					}
				}
			}
		}
		if (substr($_[0],0,1) eq '"') {
			substr($_[0],0,1)	= '';
		} else {
			throw RDF::Trine::Error::ParserError -text => qq[Ending double quote not found at line $lineno];
		}
		
		if ($_[0] =~ m/^@([a-z]+(-[a-zA-Z0-9]+)*)/) {
			my $lang	= $1;
			substr($_[0],0,1+length($lang))	= '';
			return RDF::Trine::Node::Literal->new($value, $lang);
		} elsif (substr($_[0],0,3) eq '^^<') {
			substr($_[0],0,3)	= '';
			my ($uri)	= $_[0] =~ m/^([^>]*)>/;
			substr($_[0], 0, length($uri)+1)	= '';
			return RDF::Trine::Node::Literal->new($value, undef, $uri);
		} else {
			return RDF::Trine::Node::Literal->new($value);
		}
	} else {
		throw RDF::Trine::Error::ParserError -text => qq[Not valid N-Triples node start character '$char' at line $lineno, near "$_[0]"];
	}
}

sub _unescape {
	my $string	= shift;
	my $lineno	= shift;
	my $value	= '';
	while (length($string)) {
		while ($string =~ m/^([^\\]+)/) {
			$value	.= $1;
			substr($string,0,length($1))	= '';
		}
		if (length($string)) {
			if ($string eq '\\') {
				throw RDF::Trine::Error::ParserError -text => qq[Backslash in N-Triples node without escaped character at line $lineno];
			}
			if ($string =~ m/^\\([tbnrf"'uU])/) {
				while ($string =~ m/^\\([tbnrf"'uU])/) {
					if ($1 eq 't') {
						$value	.= "\t";
						substr($string,0,2)	= '';
					} elsif ($1 eq 'b') {
						$value	.= "\b";
						substr($string,0,2)	= '';
					} elsif ($1 eq 'n') {
						$value	.= "\n";
						substr($string,0,2)	= '';
					} elsif ($1 eq 'r') {
						$value	.= "\r";
						substr($string,0,2)	= '';
					} elsif ($1 eq 'f') {
						$value	.= "\f";
						substr($string,0,2)	= '';
					} elsif ($1 eq '"') {
						$value	.= '"';
						substr($string,0,2)	= '';
					} elsif ($1 eq '\\') {
						$value	.= "\\";
						substr($string,0,2)	= '';
					} elsif ($1 eq 'u') {
						$string =~ m/^\\u([0-9A-F]{4})/ or throw RDF::Trine::Error::ParserError -text => qq[Bad N-Triples \\u escape at line $lineno, near "$string"];
						$value	.= chr(oct('0x' . $1));
						substr($string,0,6)	= '';
					} elsif ($1 eq 'U') {
						$string =~ m/^\\U([0-9A-F]{8})/ or throw RDF::Trine::Error::ParserError -text => qq[Bad N-Triples \\U escape at line $lineno, near "$string"];
						$value	.= chr(oct('0x' . $1));
						substr($string,0,10)	= '';
					}
				}
			} else {
				my $esc	= substr($string, 0, 2);
				throw RDF::Trine::Error::ParserError -text => qq[Not a valid N-Triples escape sequence '$esc' at line $lineno, near "$string"];
			}
		}
	}
	return $value;
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
