#!/usr/bin/perl
use strict;
use warnings;
no warnings 'redefine';
use URI::file;
use Test::More tests => 32;

use Data::Dumper;
use IO::Socket::INET;
use Time::HiRes qw(sleep);
use RDF::Trine;
use RDF::Trine::Iterator qw(sgrep smap swatch);
use RDF::Trine::Iterator::Graph;
use RDF::Trine::Iterator::Bindings;
use RDF::Trine::Iterator::Boolean;

my $BASE_PORT	= 9015;

{
	my $string	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="p"/>
	<variable name="name"/>
</head>
<results>
		<result>
			<binding name="p"><bnode>r1196945277r60184r136</bnode></binding>
			<binding name="name"><literal datatype="http://www.w3.org/2000/01/rdf-schema#Literal">Adam</literal></binding>
		</result>
		<result>
			<binding name="p"><uri>http://kasei.us/about/foaf.xrdf#greg</uri></binding>
			<binding name="name"><literal xml:lang="en">Greg</literal></binding>
		</result>
</results>
</sparql>
END
	my $stream	= RDF::Trine::Iterator->from_string( $string )->materialize;
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	ok( $stream->is_bindings, 'is_bindings' );
	my @values	= $stream->get_all;
	is( scalar(@values), 2, 'expected result count' );
	
	{
		my $data	= $stream->next;
		my $lit		= $data->{name};
		is( $lit->literal_value, 'Adam', 'name 1' );
		is( $lit->literal_datatype, 'http://www.w3.org/2000/01/rdf-schema#Literal', 'datatype' );
	}

	{
		my $data	= $stream->next;
		my $lit		= $data->{name};
		is( $lit->literal_value, 'Greg', 'name 2' );
		is( $lit->literal_value_language, 'en', 'language' );
	}
}

{
	my $string	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head></head>
<results>
	<boolean>true</boolean>
</results>
</sparql>
END
	my $stream	= RDF::Trine::Iterator->from_string( $string );
	isa_ok( $stream, 'RDF::Trine::Iterator' );
	ok( $stream->is_boolean, 'is_boolean' );
	ok( $stream->get_boolean, 'expected result boolean' );
}

{
	my $string	= <<"END";
<?xml version="1.0"?>
<sparql xmlns="http://www.w3.org/2005/sparql-results#">
<head>
	<variable name="p"/>
	<variable name="name"/>
	<link href="data:text/xml,%3Cextra%20name=%22bnode-map%22%3E%0A%09%3Cextrakey%20id=%22(r1201576432r20999r58)%22%3E!&amp;lt;http://xmlns.com/foaf/0.1/aimChatID%3E&amp;quot;colonelklink08&amp;quot;%3C/extrakey%3E%0A%09%3Cextrakey%20id=%22(r1201576432r20999r89)%22%3E!&amp;lt;http://xmlns.com/foaf/0.1/mbox_sha1sum%3E&amp;quot;f1f61020b9e2519b148b1acdddec6cedaac204f2&amp;quot;%3C/extrakey%3E%0A%09%3Cextrakey%20id=%22&amp;lt;http://kasei.us/about/foaf.xrdf%23greg%3E%22%3E&amp;lt;http://kasei.us/about/foaf.xrdf%23greg%3E,&amp;lt;http://kasei.us/about/foaf.xrdf%23greg%3E,&amp;lt;http://kasei.us/about/foaf.xrdf%23greg%3E,&amp;lt;http://kasei.us/about/foaf.xrdf%23greg%3E%3C/extrakey%3E%0A%3C/extra%3E%0A" />

</head>
<results>
		<result>
			<binding name="p"><uri>http://kasei.us/about/foaf.xrdf#greg</uri></binding>
			<binding name="name"><literal>Gregory Todd Williams</literal></binding>
		</result>
</results>
</sparql>
END
	my $stream	= RDF::Trine::Iterator->from_string( $string );
	isa_ok( $stream, 'RDF::Trine::Iterator::Bindings' );
	my $extra	= $stream->extra_result_data;
	is_deeply(
		$extra,
		{
			'bnode-map'	=> [{
				'(r1201576432r20999r58)' => ['!<http://xmlns.com/foaf/0.1/aimChatID>"colonelklink08"'],
				'(r1201576432r20999r89)' => ['!<http://xmlns.com/foaf/0.1/mbox_sha1sum>"f1f61020b9e2519b148b1acdddec6cedaac204f2"'],
				'<http://kasei.us/about/foaf.xrdf#greg>' => ['<http://kasei.us/about/foaf.xrdf#greg>,<http://kasei.us/about/foaf.xrdf#greg>,<http://kasei.us/about/foaf.xrdf#greg>,<http://kasei.us/about/foaf.xrdf#greg>']
			}]
		},
		'identity hints'
	);
}

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
		my $stream	= RDF::Trine::Iterator->from_handle_incremental( $in, 128 );
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
			my $stream	= RDF::Trine::Iterator->from_handle_incremental( $in, 1024 );
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
