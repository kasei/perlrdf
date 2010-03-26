# RDF::Trine::Parser::NTriples
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::NTriples - N-Triples Parser.

=head1 VERSION

This document describes RDF::Trine::Parser::NTriples version 0.118

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'ntriples' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

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

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.118';
	$RDF::Trine::Parser::parser_names{ 'ntriples' }	= __PACKAGE__;
	foreach my $type (qw(text/plain)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my $self = bless( {}, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

=item C<< parse_file_into_model ( $base_uri, $fh, $model [, context => $context] ) >>

Parses all data read from the filehandle C<< $fh >>, using the given
C<< $base_uri >>. For each RDF statement parsed, will call
C<< $model->add_statement( $statement ) >>.

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

=item C<< parse_file ( $base, $fh, \&handler ) >>

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;
	
	my $lineno	= 0;
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
			while (my $n = $self->_eat_node( $lineno, $line )) {
				push(@nodes, $n);
				$line	=~ s/^\s*//;
			}
		};
		$line	=~ s/^\s//g;
		unless ($line eq '.') {
# 			warn Dumper(\@nodes, $line);
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
		$st	= RDF::Trine::Statement->new( @$nodes );
# 	} elsif (scalar(@$nodes) == 4) {
# 		$st	= RDF::Trine::Statement::Quad->new( @$nodes );
	} else {
# 		warn Dumper($nodes);
		throw RDF::Trine::Error::ParserError -text => "Not valid N-Triples data at line $lineno";
	}
	$handler->( $st );
}

sub _eat_node {
	my $self	= shift;
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
						$_[0] =~ m/^\\u([0-9A-F]{4})/ or throw RDF::Trine::Error::ParserError -text => "Bad N-Triples \\u escape at line $lineno";
						$value	.= chr(oct('0x' . $1));
						substr($_[0],0,6)	= '';
					} elsif ($1 eq 'U') {
						$_[0] =~ m/^\\U([0-9A-F]{8})/ or throw RDF::Trine::Error::ParserError -text => "Bad N-Triples \\U escape at line $lineno";
						$value	.= chr(oct('0x' . $1));
						substr($_[0],0,10)	= '';
					} else {
						die $_[0];
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
		throw RDF::Trine::Error::ParserError -text => "Not valid N-Triples node start character '$char' at line $lineno";
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
			while ($string =~ m/^\\(.)/) {
				if ($1 eq 't') {
					$value	.= "\t";
					substr($string,0,2)	= '';
				} elsif ($1 eq 'r') {
					$value	.= "\r";
					substr($string,0,2)	= '';
				} elsif ($1 eq 'n') {
					$value	.= "\n";
					substr($string,0,2)	= '';
				} elsif ($1 eq '"') {
					$value	.= '"';
					substr($string,0,2)	= '';
				} elsif ($1 eq '\\') {
					$value	.= "\\";
					substr($string,0,2)	= '';
				} elsif ($1 eq 'u') {
					$string =~ m/^\\u([0-9A-F]{4})/ or throw RDF::Trine::Error::ParserError -text => "Bad N-Triples \\u escape at line $lineno";
					$value	.= chr(oct('0x' . $1));
					substr($string,0,6)	= '';
				} elsif ($1 eq 'U') {
					$string =~ m/^\\U([0-9A-F]{8})/ or throw RDF::Trine::Error::ParserError -text => "Bad N-Triples \\U escape at line $lineno";
					$value	.= chr(oct('0x' . $1));
					substr($string,0,10)	= '';
				} else {
					die $string;
				}
			}
		}
	}
	return $value;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
