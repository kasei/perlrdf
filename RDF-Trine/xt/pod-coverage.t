use strict;
use warnings;
use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
use Module::Load::Conditional qw[can_load];

my @modules	= all_modules();
foreach my $mod (@modules) {
	if (can_load( modules => { $mod => 0 } )) {
		pod_coverage_ok($mod, { also_private => [ qr{^[A-Z][A-Z0-9_]*$} ] });
	} else {
		note("Ignoring $mod for POD coverage tests (failed to load)");
	}
}

done_testing();
