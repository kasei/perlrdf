package RDF::Query::Util;

use strict;
use warnings;
no warnings 'redefine';
use Carp qw(carp croak confess);

use RDF::Query;

sub cli_parse_args {
	my %args;
	return unless (@ARGV);
	while ($ARGV[0] =~ /^-(\w+)$/) {
		my $opt	= shift(@ARGV);
		if ($opt eq '-e') {
			$args{ query }	= shift(@ARGV);
		} elsif ($opt eq '-l') {
			$args{ lang }	= shift(@ARGV);
		} elsif ($opt eq '-o') {
			$args{ optimize }	= 1;
		}
	}
	
	unless (defined($args{query})) {
		my $file	= shift(@ARGV);
		my $sparql	= ($file eq '-')
					? do { local($/) = undef; <> }
					: do { local($/) = undef; open(my $fh, '<', $file) || die $!; binmode($fh, ':utf8'); <$fh> };
		$args{ query }	= $sparql;
	}
	return %args;
}

sub cli_get_query {
	my %args	= cli_parse_args();
	return $args{ query };
}

1;
