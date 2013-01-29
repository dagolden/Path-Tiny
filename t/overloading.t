use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use Path::Tiny;

my $path = path("t/stringify.t");

is( "$path", "t/stringify.t", "stringify via overloading" );
is( $path->stringify, "t/stringify.t", "stringify via method" );
ok( $path, "boolifies to true" );


done_testing;
# COPYRIGHT
