use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use Path::Tiny;

my $rel1 = path(".");
my $abs1 = $rel1->absolute;
is ( $abs1->absolute, $abs1, "absolute of absolute is identity" );

my $rel2 = $rel1->child("t");
my $abs2 = $rel2->absolute;

is( $rel2->absolute( $abs1 ), $abs2, "absolute on base" );


done_testing;
# COPYRIGHT
