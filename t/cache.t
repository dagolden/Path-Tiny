use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Scalar::Util qw(refaddr);

use lib 't/lib';
use TestUtils;

use Path::Tiny;

subtest "cache clearing" => sub {
    my $file = "foo/bar";

    my $inner_refaddr;
    {
        my $inner1 = path($file);
        my $inner2 = path($file);
        is refaddr($inner1), refaddr($inner2);
        $inner_refaddr = refaddr($inner1);
    }

    # Just to make sure Perl doesn't reuse the same address.
    my $junk = path("something/else");
    my($this, $that, $other) = (23, 42, 99);

    my $outer1 = path($file);
    isnt refaddr($outer1), $inner_refaddr;
};

done_testing;
