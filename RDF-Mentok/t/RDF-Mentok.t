# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl RDF-Mentok.t'

#########################

# change 'tests => 2' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('RDF::Mentok') };


my $fail = 0;
foreach my $constname (qw(
	RDF_ITER_FLAGS_BOUND_A RDF_ITER_FLAGS_BOUND_B RDF_ITER_FLAGS_BOUND_C
	THREADED_BATCH_SIZE)) {
  next if (eval "my \$a = $constname; 1");
  if ($@ =~ /^Your vendor has not defined RDF::Mentok macro $constname/) {
    print "# pass: $@";
  } else {
    print "# fail: $@";
    $fail = 1;
  }

}

ok( $fail == 0 , 'Constants' );
#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

{
	my $m	= RDF::Mentok::test();
	is( $m, '13', 'magic test value' );
}

{
	my $m	= RDF::Mentok::new_model();
	isa_ok( $m, 'RDF::Mentok' );

#	$m->load_file( "/Users/samofool/foaf.xrdf" );
	my $start	= time;
	$m->load_file( "/Users/samofool/barton-fixed3-250k.nt" );
	my $elapsed	= (time - $start);
	warn "$elapsed seconds to load " . $m->size . " triples\n";
}

