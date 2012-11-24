use strict;
use warnings;
use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
use Devel::Peek;
all_pod_coverage_ok({ also_private => [ qr{^[A-Z][A-Z0-9_]*$} ] });
