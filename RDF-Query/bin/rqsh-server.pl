#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use lib qw(../lib lib);

use Cwd;
use Net::hostent;
use IO::Socket::INET;
use Scalar::Util qw(blessed);
use Data::Dumper;
use RDF::Query;
use RDF::Query::Error qw(:try);
use RDF::Query::Util;
use Term::ReadLine;
use Term::ReadKey;

################################################################################
# Log::Log4perl::init( \q[
# 	log4perl.category.rdf.query.plan				= DEBUG, Screen
# 	log4perl.appender.Screen						= Log::Log4perl::Appender::Screen
# 	log4perl.appender.Screen.stderr					= 0
# 	log4perl.appender.Screen.layout					= Log::Log4perl::Layout::SimpleLayout
# ] );
################################################################################

$|			= 1;
my $model	= memory_model();
my %args	= ( update => 1, base => 'http://myrdf.us/rqsh/' );

my $def_format	= 'ntriples';
my $serializer	= RDF::Trine::Serializer->new($def_format);
my %serializer	= ($def_format => $serializer);
my $class	= delete $args{ class } || 'RDF::Query';



$SIG{CHLD} = 'IGNORE';
my $port	= 8082;
my $server	= IO::Socket::INET->new(
	LocalPort => $port,
	Type      => SOCK_STREAM,
	Reuse     => 1,
	Listen    => 10,
) or die "Couln't start server: $!\n";

print "rqsh server started on port $port\n";

my $client;
while ($client = $server->accept) {
	my $hostinfo	= gethostbyaddr($client->peeraddr);
	printf "[Connect from %s]\n", $hostinfo ? $hostinfo->name : $client->peerhost;
	unless (my $pid = fork) {
		open STDERR, '>&STDOUT';
		handle( $client );
		$client->shutdown(2);
		close($client);
		exit;
	}
}

exit;


sub handle {
	my $handle	= shift;
	my $term	= Term::ReadLine->new('rqsh', $handle, $handle);
	select($handle);
	print {$handle} "rqsh v1.0\n\n";
	while ( defined ($_ = $term->readline('rqsh> ')) ) {
		my $line	= $_;
		next unless (length($line));
		if ($line =~ /exit|close/i) {
			return;
		} elsif ($line =~ /help/i) {
			help();
		} elsif ($line =~ /^explain (.*)$/i) {
			explain($model, $term, $1);
# 		} elsif ($line =~ /^use (\w+)\s*;?\s*$/i) {
# 			my $name	= $1;
# 			my $nmodel	= model( $name );
# 			if ($nmodel) {
# 				$model	= $nmodel;
# 			}
# 		} elsif ($line =~ /init/i) {
# 			init( $model, $term, $line );
		} elsif ($line =~ m/^serializer (\w+)$/i) {
			if (exists($serializer{ $1 })) {
				$serializer	= $serializer{ $1 };
			} else {
				my $ser;
				try {
					$ser	= RDF::Trine::Serializer->new( $1 );
				} catch RDF::Trine::Error::SerializationError with {};
				if ($ser) {
					$serializer{ $1 }	= $ser;
					$serializer			= $ser;
				} else {
					print {$handle} "Unrecognized serializer name '$1'\n";
					print {$handle} "Valid serializers are:\n";
					foreach my $name (RDF::Trine::Serializer->serializer_names) {
						print {$handle} "    $name\n";
					}
					print {$handle} "\n";
				}
			}
		} elsif ($line =~ /debug/i) {
			debug( $model, $term, $line );
		} else {
			query( $model, $term, $line );
		}
	}
}

sub help {
	print <<"END";
Commands:
    help                Show this help information.
    serializer [format] Set the serializer used for RDF results (e.g. "serializer turtle").
    debug               Print all the quads in the storage backend.
    explain [sparql]    Explain the execution plan for the SPARQL 1.1 query/update.
    SELECT ...          Execute the SPARQL 1.1 query.
    ASK ...             Execute the SPARQL 1.1 query.
    CONSTRUCT ...       Execute the SPARQL 1.1 query.
    DESCRIBE ...        Execute the SPARQL 1.1 query.
    INSERT ...          Execute the SPARQL 1.1 update.
    DELETE ...          Execute the SPARQL 1.1 update.
    LOAD <uri>          Execute the SPARQL 1.1 update.
    CLEAR ...           Execute the SPARQL 1.1 update.

END
}

sub init {
	my $model	= shift;
	my $term	= shift;
	my $line	= shift;
	if (my $store = $model->_store) {
		$store->init;
	}
}

# sub model {
# 	my $term	= shift;
# 	my $name	= shift;
# 	my $sclass	= RDF::Trine::Store->class_by_name( $name );
# 	if ($sclass) {
# 		if ($sclass eq 'RDF::Trine::Store::Memory') {
# 			$model	= memory_model();
# 			return;
# 		} else {
# 			if ($sclass->can('_config_meta')) {
# 				my $meta	= $sclass->_config_meta;
# 				my $keys	= $meta->{required_keys};
# 				my $config	= {};
# 				foreach my $k (@$keys) {
# 					get_value( $term, $meta, $k, $config );
# 				}
# 				my $store	= eval { $sclass->new_with_config( $config ) };
# 				if ($store) {
# 					my $m		= RDF::Trine::Model->new( $store );
# 					if ($m) {
# 						return $m;
# 					}
# 				}
# 				print "Failed to construct '$name'-backed model.\n";
# 				return;
# 			} else {
# 				print "Cannot construct model from '$name' storage class.\n";
# 			}
# 		}
# 	} else {
# 		print "No storage class named '$name' found\n";
# 		return;
# 	}
# }

sub explain {
	my $model	= shift;
	my $term	= shift;
	my $sparql	= shift;
	my $psparql	= join("\n", $RDF::Query::Util::PREFIXES, $sparql);
	my $query	= $class->new( $psparql, \%args );
	unless ($query) {
		print "Error: " . RDF::Query->error . "\n";
		return;
	}
	my ($plan, $ctx)	= $query->prepare( $model );
	print $plan->sse . "\n";
}

sub query {
	my $model	= shift;
	my $term	= shift;
	my $sparql	= shift;
	my $psparql	= join("\n", $RDF::Query::Util::PREFIXES, $sparql);
	my $query	= $class->new( $psparql, \%args );
	unless ($query) {
		print "Error: " . RDF::Query->error . "\n";
		return;
	}
	$term->addhistory($sparql);
	try {
		my ($plan, $ctx)	= $query->prepare($model);
		my $iter	= $query->execute_plan( $plan, $ctx );
		my $count	= -1;
		if (blessed($iter)) {
			if ($iter->isa('RDF::Trine::Iterator::Graph')) {
				$serializer->serialize_iterator_to_file( $term->OUT, $iter );
			} else {
				print $iter->as_string( 0, \$count );
			}
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

sub debug {
	my $model	= shift;
	my $term	= shift;
	my $line	= shift;
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
}

sub get_value {
	my $term	= shift;
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
			get_value( $term, $meta, $sk, $config );
		}
		while ($template =~ m/\[%(\w+)%\]/) {
			my $key	= $1;
			my $v	= $config->{$key};
			$template	=~ s/\[%$key%\]/$v/e;
		}
		$config->{ $k }	= $template;
	} else {
		my $desc	= $meta->{fields}{$k}{description};
		my $type	= $meta->{fields}{$k}{type};
		my $value;
		if ($type eq 'password') {
			print "$desc: ";
			$value	= ReadLine(0, $term->IN);
			chomp($value);
		} elsif ($type eq 'filename') {
			my $attribs	= $term->Attribs;
			local($attribs->{completion_entry_function})	= $attribs->{filename_completion_function};
			$value	= $term->readline("$desc: ");
		} else {
			$value = $term->readline("$desc: ")
		}
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
