use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Fatal;

use Path::Tiny;

my $err;

$err = exception { path("aljfakdlfadks")->slurp };
like( $err, qr/at $0/, "exception reported at caller's package" );

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
