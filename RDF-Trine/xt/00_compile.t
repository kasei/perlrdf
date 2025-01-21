use strict;
use warnings;
use Test::More;

use Module::Load::Conditional qw[can_load];
unless (can_load( modules => { 'Test::Compile' => 0 })) {
  plan skip_all => "Test::Compile must be installed for compilation tests";
}
Test::Compile->import;
pm_file_ok($_) for grep { !m/Redland|mysql|Pg|Redis/ } all_pm_files();
done_testing();
