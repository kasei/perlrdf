#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use lib qw(../lib lib);

use Cwd;
use Scalar::Util qw(blessed);
use Data::Dumper;
use RDF::Query;
use RDF::Query::Error qw(:try);
use RDF::Query::Util;
use Term::ReadLine;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan				= DEBUG, Screen
# 	log4perl.appender.Screen						= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr					= 0
# 	log4perl.appender.Screen.layout					= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

$|			= 1;
my $model;
if (scalar(@ARGV) and $ARGV[ $#ARGV ] =~ /.sqlite/) {
	my $file	= pop(@ARGV);
	my $dsn		= "DBI:SQLite:dbname=" . $file;
	my $store	= RDF::Trine::Store::DBI->new($model, $dsn, '', '');
	$model		= RDF::Trine::Model->new( $store );
} else {
	$model			= memory_model();
}
my %args	= &RDF::Query::Util::cli_parse_args();
unless (exists $args{update}) {
	$args{update}	= 1;
}
$args{ base }	= 'file://' . getcwd . '/';

my $class	= delete $args{ class } || 'RDF::Query';
my $term	= Term::ReadLine->new('rqsh');

while ( defined ($_ = $term->readline('rqsh> ')) ) {
	my $sparql	= $_;
	next unless (length($sparql));
	if ($sparql eq 'debug') {
		print "# model = $model\n";
		if (my $store = $model->_store) {
			print "# store = $store\n";
		}
		my $iter	= $model->get_statements( undef, undef, undef, undef );
		my @rows;
		my @names	= qw[subject predicate object context];
		while (my $row = $iter->next) {
			push(@rows, [map {$row->$_()->as_string} @names]);
		}
		my @rule			= qw(- +);
		my @headers			= (\q"| ");
		push(@headers, map { $_ => \q" | " } @names);
		pop	@headers;
		push @headers => (\q" |");
		my $table = Text::Table->new(@names);
		$table->rule(@rule);
		$table->body_rule(@rule);
		$table->load(@rows);
		print join('',
				$table->rule(@rule),
				$table->title,
				$table->rule(@rule),
				map({ $table->body($_) } 0 .. @rows),
				$table->rule(@rule)
			);
		my $size	= scalar(@rows);
		print "$size statements\n";
	} elsif ($sparql =~ /^use (\w+)\s*;?\s*$/) {
		my $name	= $1;
		my $sclass	= RDF::Trine::Store->class_by_name( $name );
		if ($sclass) {
			if ($sclass eq 'RDF::Trine::Store::Memory') {
				$model	= memory_model();
				next;
			} else {
				if ($sclass->can('_config_meta')) {
					my $meta	= $sclass->_config_meta;
					my $keys	= $meta->{required_keys};
					my $config	= {};
					foreach my $k (@$keys) {
						get_value( $meta, $k, $config );
					}
					my $store	= $sclass->new_with_config( $config );
					my $m		= RDF::Trine::Model->new( $store );
					if ($m) {
						$model	= $m;
						next;
					} else {
						print "Failed to construct '$name'-backed model.\n";
						next;
					}
				} else {
					print "Cannot construct model from '$name' storage class.\n";
				}
			}
		} else {
			print "No storage class named '$name' found\n";
			next;
		}
	} else {
		my $psparql	= join("\n", $RDF::Query::Util::PREFIXES, $sparql);
		my $query	= $class->new( $psparql, \%args );
		unless ($query) {
			print "Error: " . RDF::Query->error . "\n";
			next;
		}
		$term->addhistory($sparql);
		try {
			my ($plan, $ctx)	= $query->prepare($model);
			my $iter	= $query->execute_plan( $plan, $ctx );
			my $count	= -1;
			if (blessed($iter)) {
				print $iter->as_string( 0, \$count );
			}
			if ($plan->is_update) {
				my $size	= $model->size;
				print "$size statements\n";
			} elsif ($count >= 0) {
				print "$count results\n";
			}
		} catch RDF::Query::Error with {
			my $e	= shift;
			print "Error: $e\n";
		} otherwise {
			warn "died: " . Dumper(\@_);
		};
	}
}


sub get_value {
	my $meta	= shift;
	my $k		= shift;
	my $config	= shift;
	if (my $v = $config->{$k}) {
		return;
	} elsif (defined($meta->{fields}{$k}{'value'})) {
		$config->{ $k }	= $meta->{fields}{$k}{'value'};
	} elsif (defined($meta->{fields}{$k}{'template'})) {
		my $template	= $meta->{fields}{$k}{'template'};
		my @subkeys	= ($template =~ m/\[%(\w+)%\]/g);
		foreach my $sk (@subkeys) {
			get_value( $meta, $sk, $config );
		}
		while ($template =~ m/\[%(\w+)%\]/) {
			my $key	= $1;
			my $v	= $config->{$key};
			$template	=~ s/\[%$key%\]/$v/e;
		}
		$config->{ $k }	= $template;
	} else {
		my $desc	= $meta->{fields}{$k}{description};
		print "$desc: ";
		my $value	= <>;
		chomp($value);
		$config->{ $k }	= $value;
	}
}

{ my $memory_model;
sub memory_model {
	if (defined($memory_model)) {
		return $memory_model;
	} else {
		my $model			= RDF::Trine::Model->temporary_model;
		$memory_model	= $model;
		return $model;
	}
}}
