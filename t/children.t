use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Basename ();
use File::Temp ();
use File::Spec::Unix;

use Path::Tiny;

my $tempdir = File::Temp->newdir;

my @kids = qw/apple banana carrot/;
path($tempdir)->child($_)->touch for @kids;

my @expected = map { path( File::Spec::Unix->catfile( $tempdir, $_ ) ) } @kids;

is_deeply(
    [ sort { $a cmp $b } path($tempdir)->children ],
    [ sort @expected ],
    "children correct"
);

my $regexp = qr/.a/;
is_deeply(
    [ sort { $a cmp $b } path($tempdir)->children($regexp) ],
    [ sort grep { my $child = File::Basename::basename($_); $child =~ /$regexp/ } @expected ],
    "children correct with Regexp argument"
);

my $arrayref = [];
eval { path($tempdir)->children($arrayref) };
like $@, qr/Invalid argument '\Q$arrayref\E' for children()/, 'children with invalid argument';

done_testing;
# COPYRIGHT
