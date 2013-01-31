use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use Path::Tiny;

my @cases = (
    "absolute" => [ "/foo/bar" => "/foo" => "/" => "/" ],
);

while ( @cases ) {
    my ($label, $list) = splice(@cases, 0, 2);
    subtest $label => sub {
        my $path = path(shift @$list);
        while ( @$list ) {
            my $parent = shift @$list;
            is ( $path->parent, $parent, "$path -> $parent" );
            $path = path($parent);
        }
    };
}

done_testing;
# COPYRIGHT
