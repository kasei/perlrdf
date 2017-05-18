#!/usr/bin/env perl

=head1 NAME

turtle_tokenize.pl - Tokenization tool for Turtle files

=head1 USAGE

 turtle_tokenize.pl FILE [LIMIT]

Prints each turtle token contained in the input FILE to a separate line of output.
If LIMIT is specified, exits after LIMIT tokens have been output.

=cut

use strict;
use warnings;
use RDF::Trine;
use RDF::Trine::Parser::Turtle::Lexer;
use RDF::Trine::Parser::Turtle::Constants;

use Scalar::Util qw(blessed);
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;
use File::Spec;

$|				= 1;
my $verbose		= 0;
my $filename	= shift;
my $limit		= shift || 0;
open(my $fh, '<:encoding(UTF-8)', $filename) or die $!;
my $count	= 0;
my $t0		= [gettimeofday];

my $l		= RDF::Trine::Parser::Turtle::Lexer->new( file => $fh );
eval {
	while (my $t = $l->get_token) {
		$count++;
		printf("%3d:%-3d %3d:%-3d %s", $t->start_line, $t->start_column, $t->line, $t->column, decrypt_constant($t->type));
		if (defined(my $v = $t->value)) {
			printf("\t%s", $v);
		}
		print "\n";
		throw Error if ($limit and $count >= $limit);
	}
};

if ($@) {
	my $e	= $@;
	if (blessed($e) and $e->isa('RDF::Trine::Error::ParserError::Tokenized')) {
		$e->explain($fh);
	} else {
		warn $@;
	}
}

my $elapsed	= tv_interval( $t0, [gettimeofday]);
print STDERR sprintf("\n%d triples parsed in %.3fs (%.1f T/s)\n", $count, $elapsed, ($count/$elapsed));
