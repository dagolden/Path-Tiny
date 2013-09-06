use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;

my $err;

$err = exception { path("aljfakdlfadks")->slurp };
like( $err, qr/at \Q$0\E/, "exception reported at caller's package" );

for my $m ( qw/append iterator lines lines_raw lines_utf8 slurp spew/ ) {
    $err = exception { path("foo")->$m({ wibble => 1 }) };
    like( $err, qr/Invalid option\(s\) for $m: wibble/, "$m bad args" );
}

# exclude append/spew because they handle hash/not-hash themselves
for my $m ( qw/iterator lines lines_raw lines_utf8 slurp/ ) {
    my $scalar = [ qw/array ref/ ];
    $err = exception { path("foo")->$m($scalar) };
    like( $err, qr/Options for $m must be a hash reference/, "$m not hashref" );
}

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
