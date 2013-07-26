use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Deep '!blessed';
use File::Basename ();
use File::Temp ();
use File::Spec::Unix;

use Path::Tiny;

my $tempdir = File::Temp->newdir;

my @kids = qw/apple banana carrot/;
path($tempdir)->child($_)->touch for @kids;

my @expected = map { path( File::Spec::Unix->catfile( $tempdir, $_ ) ) } @kids;

cmp_deeply(
    [ sort { $a cmp $b } path($tempdir)->children ],
    [ sort @expected ],
    "children correct"
);

my $regexp = qr/.a/;
cmp_deeply(
    [ sort { $a cmp $b } path($tempdir)->children($regexp) ],
    [ sort grep { my $child = File::Basename::basename($_); $child =~ /$regexp/ } @expected ],
    "children correct with Regexp argument"
);

path($tempdir)->child('apple')->spew_raw("1$/2$/3$/4$/5$/");
path($tempdir)->child('banana')->spew_raw("1$/2$/");
path($tempdir)->child('carrot')->spew_raw("1$/2$/3$/");
my $coderef = sub {
    my ( $parent, $child ) = @_;
    return 1 if $parent->child($child)->lines > 2;
};
cmp_deeply(
    [ sort { $a cmp $b } path($tempdir)->children($coderef) ],
    [ sort grep { $coderef->( path($tempdir), File::Basename::basename($_) ) } @expected ],
    "children correct with code reference argument"
);

eval { path($tempdir)->children(q{}) };
like $@, qr/Invalid argument for children()/, 'children with invalid argument';

done_testing;
# COPYRIGHT
