use strict;
use warnings;
use Test::More;
eval "use Test::Compile";
Test::More->builder->BAIL_OUT("Test::Compile required for testing compilation") if $@;
pm_file_ok($_) for grep { !m/Redland|mysql|Pg|Redis/ } all_pm_files();
