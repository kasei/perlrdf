#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 20;

use Data::Dumper;
use IO::Socket::INET;
use Time::HiRes qw(sleep);

use RDF::Trine;
use RDF::Trine::Iterator::Incremental;

my $BASE_PORT	= 9015;


SKIP: {
	eval "use XML::SAX::Expat::Incremental";
	if ($@) {
		skip "Incremental parsing requires XML::SAX::Expat::Incremental", 20;
	}
	SKIP: {
		my $port	= $BASE_PORT + 1;
		my $listen	= IO::Socket::INET->new( Listen => 5, LocalAddr => 'localhost', LocalPort => $port, Proto => 'tcp', ReuseAddr => 1 );
		unless ($listen) {
			skip "Can't open loopback socket", 9;
		}
		my $out		= IO::Socket::INET->new( PeerAddr => 'localhost', PeerPort => $port, Proto => 'tcp' );
		my $in		= $listen->accept;
		$out->send( <<"END" );
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="name"/>
</head>
END
		my $stream	= RDF::Trine::Iterator::Incremental->new( $in, 128 );
		isa_ok( $stream, 'RDF::Trine::Iterator::Bindings' );
		
		$out->send( <<"END" );
	<results>
			<result>
				<binding name="name"><literal>Alice</literal></binding>
			</result>
	</results>
END
		
		{
			my $data	= $stream->next;
			isa_ok( $data, 'HASH' );
			isa_ok( $data->{name}, 'RDF::Trine::Node::Literal' );
			is( $data->{name}->literal_value, 'Alice' );
		}
		
		{
			my $delay	= 3;
			my $start	= time();
			print "# beginning $delay-second timeout test.\n";
			if (my $pid = fork()) {
				my $data	= $stream->next;
				my $end		= time();
				isa_ok( $data, 'HASH' );
				isa_ok( $data->{name}, 'RDF::Trine::Node::Literal' );
				is( $data->{name}->literal_value, 'Bob' );
				cmp_ok( $end, '>=', ($start + $delay - 1), "good delay of $delay seconds" );
			} else {
				sleep $delay;
				$out->send( <<"END" );
				<results>
					<result><binding name="name"><literal>Bob</literal></binding></result>
				</results>
END
				$out->close;
				exit;
			}
		}
		
		$out->send( <<"END" );
	</sparql>
END
		my $end	= $stream->next;
		is( $end, undef, 'expected eos' );
	}
	
	SKIP: {
		my $port	= $BASE_PORT + 2;
		my $listen	= IO::Socket::INET->new( Listen => 5, LocalAddr => 'localhost', LocalPort => $port, Proto => 'tcp', ReuseAddr => 1 );
		unless ($listen) {
			skip "Can't open loopback socket", 11;
		}
		my $out		= IO::Socket::INET->new( PeerAddr => 'localhost', PeerPort => $port, Proto => 'tcp' );
		my $in		= $listen->accept;
	
		print "# beginning data-rate test.\n";
		
		my $delay	= 2;
		if (my $pid = fork()) {
			my $stream	= RDF::Trine::Iterator::Incremental->new( $in, 1024 );
			isa_ok( $stream, 'RDF::Trine::Iterator::Bindings' );
			my $extra	= $stream->extra_result_data;
			isa_ok( $extra, 'HASH' );
			
			my $handler	= $extra->{Handler};
			isa_ok( $handler, 'RDF::Trine::Iterator::SAXHandler' );
			
			my $lastrate;
			my $count	= 0;
			while (my $d = $stream->next) {
				my $rate	= $handler->rate;
				if ($count < 5) {
					isa_ok( $d->{number}, 'RDF::Trine::Node::Literal' );
				}
				if ($count++ % 10 == 9) {	# only check after pulling some results so that the data rate has a chance to normalize (instead of starting out as something like 1/0.0015
					if (defined($lastrate)) {
						cmp_ok( $rate, '>=', $lastrate, 'increasing data rate' );
					}
					$lastrate	= $rate;
				}
				last if ($count > 40);
			}
		} else {
			$out->send( <<"END" );
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="number"/>
</head>
<results>
	<result><binding name="number"><literal>0</literal></binding></result>
END
			foreach my $i (1 .. 50) {
				$out->send( <<"END" );
		<result><binding name="number"><literal>${i}</literal></binding></result>
END
				sleep( $delay );
				$delay	*= 0.8;
			}
			$out->close;
			exit;
		}
	}
}
