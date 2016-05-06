use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Config;

use lib 't/lib';
use TestUtils qw/exception pushd tempd/;

use Path::Tiny;

# absolute() tests

my $rel1 = path(".");
my $abs1 = $rel1->absolute;
is( $abs1->absolute, $abs1, "absolute of absolute is identity" );

my $rel2 = $rel1->child("t");
my $abs2 = $rel2->absolute;

is( $rel2->absolute($abs1), $abs2, "absolute on base" );

# Note: in following relative() tests, capital 'A', 'B' denotes absolute path
# and lower case 'a', 'b' denotes relative paths. 'R' denotes the root
# directory. When there are multiple
# letters together, they indicate how paths relate in the hierarchy:
# A subsumes AB, ABC and ABD have a common prefix (referred to as AB).
# The presence of an underscore indicates a symlink somewhere in that segment
# of a path: ABC_D indicates a symlink somewhere between ABC and ABC_D.

my @symlink_free_cases = (
    # identical (absolute and relative cases)
    [ "A->rel(A)", "/foo/bar", "/foo/bar", "." ],
    [ "a->rel(a)", "foo/bar",  "foo/bar",  "." ],
    # descends -- absolute
    [ "AB->rel(A)", "/foo/bar/baz", "/",        "foo/bar/baz" ],
    [ "AB->rel(A)", "/foo/bar/baz", "/foo",     "bar/baz" ],
    [ "AB->rel(A)", "/foo/bar/baz", "/foo/bar", "baz" ],
    # descends -- relative
    [ "ab->rel(a)", "foo/bar/baz", "",        "foo/bar/baz" ],
    [ "ab->rel(a)", "foo/bar/baz", ".",       "foo/bar/baz" ],
    [ "ab->rel(a)", "foo/bar/baz", "foo",     "bar/baz" ],
    [ "ab->rel(a)", "foo/bar/baz", "foo/bar", "baz" ],
    # common prefix -- absolute (same volume)
    [ "R->rel(A)",      "/",            "/bam",             ".." ],
    [ "R->rel(AB)",     "/",            "/bam/baz",         "../.." ],
    [ "ABC->rel(D)",    "/foo/bar/baz", "/bam",             "../foo/bar/baz" ],
    [ "ABC->rel(AD)",   "/foo/bar/baz", "/foo/bam",         "../bar/baz" ],
    [ "ABC->rel(ABD)",  "/foo/bar/baz", "/foo/bar/bam",     "../baz" ],
    [ "ABC->rel(DE)",   "/foo/bar/baz", "/bim/bam",         "../../foo/bar/baz" ],
    [ "ABC->rel(ADE)",  "/foo/bar/baz", "/foo/bim/bam",     "../../bar/baz" ],
    [ "ABC->rel(ABDE)", "/foo/bar/baz", "/foo/bar/bim/bam", "../../baz" ],
    # common prefix -- relative (same volume)
    [ "abc->rel(d)",    "foo/bar/baz", "bam",             "../foo/bar/baz" ],
    [ "abc->rel(ad)",   "foo/bar/baz", "foo/bam",         "../bar/baz" ],
    [ "abc->rel(abd)",  "foo/bar/baz", "foo/bar/bam",     "../baz" ],
    [ "abc->rel(de)",   "foo/bar/baz", "bim/bam",         "../../foo/bar/baz" ],
    [ "abc->rel(ade)",  "foo/bar/baz", "foo/bim/bam",     "../../bar/baz" ],
    [ "abc->rel(abde)", "foo/bar/baz", "foo/bar/bim/bam", "../../baz" ],
    # both paths relative (not identical)
    [ "ab->rel(a)",   "foo/bar",     "foo",     "bar" ],
    [ "abc->rel(ab)", "foo/bar/baz", "foo/bim", "../bar/baz" ],
    [ "a->rel(b)",    "foo",         "bar",     "../foo" ],
);

for my $c (@symlink_free_cases) {
    my ( $label, $path, $base, $result ) = @$c;
    is( path($path)->relative($base), $result, $label );
}

my @one_rel_from_root = (
    [ "A->rel(b) from rootdir", "/foo/bar", "baz",  "../foo/bar" ],
    [ "a->rel(B) from rootdir", "foo/bar",  "/baz", "../foo/bar" ],
);

{
    my $wd = pushd("/");
    for my $c (@one_rel_from_root) {
        my ( $label, $path, $base, $result ) = @$c;
        is( path($path)->relative($base), $result, $label );
    }
}

{
    my $wd  = tempd("/");
    my $cwd = Path::Tiny::cwd->realpath;

    # A->rel(b) from tmpdir -- need to find updir from ./b to root
    my $base = $cwd->child("baz");
    my ( undef, @parts ) = split "/", $base;
    my $up_to_root = path( "../" x @parts );
    is(
        path("/foo/bar")->relative("baz"),
        $up_to_root->child("foo/bar"),
        "A->rel(b) from tmpdir"
    );

    # a->rel(B) from tempdir -- path is .. + cwd + a
    is(
        path("foo/bar")->relative("/baz"),
        path( "..", $cwd->_just_filepath, "foo/bar" ),
        "a->rel(B) from tmpdir"
    );

}

subtest "relative on absolute paths with symlinks" => sub {
    my $wd   = tempd;
    my $cwd  = path(".")->realpath;
    my $deep = $cwd->child("foo/bar/baz/bam/bim/buz/wiz/was/woz");
    $deep->mkpath();

    plan skip_all => "No symlink support"
      unless $Config{d_symlink};

    my ( $path, $base, $expect );

    # (a) symlink in common path
    #
    #   A_BCD->rel(A_BEF) - common point A_BC - result: ../../C/D
    #
    $cwd->child("A")->mkpath;
    symlink $deep, "A/B" or die "$!";
    $path = $cwd->child("A/B/C/D");
    $path->mkpath;
    is( $path->relative( $cwd->child("A/B/E/F") ), "../../C/D", "A_BCD->rel(A_BEF)" );
    $cwd->child("A")->remove_tree;
    $deep->remove_tree;
    $deep->mkpath;

    # (b) symlink in path from common to original path
    #
    #   ABC_DE->rel(ABFG) - common point AB - result: ../../C/D/E
    #
    $cwd->child("A/B/C")->mkpath;
    symlink $deep, "A/B/C/D" or die "$!";
    $path = $cwd->child("A/B/C/D/E");
    $path->mkpath;
    is( $path->relative( $cwd->child("A/B/F/G") ), "../../C/D/E",
        "ABC_DE->rel(ABC_FG)" );
    $cwd->child("A")->remove_tree;
    $deep->remove_tree;
    $deep->mkpath;

    # (c) symlink in path from common to new base; all path exist
    #
    #   ABCD->rel(ABE_FG) - common point AB -  result depends on E_F resolution
    #
    $path = $cwd->child("A/B/C/D");
    $path->mkpath;
    $cwd->child("A/B/E")->mkpath;
    symlink $deep, "A/B/E/F" or die $!;
    $base = $cwd->child("A/B/E/F/G");
    $base->mkpath;
    $expect = $path->relative( $deep->child("G") );
    is( $path->relative($base), $expect, "ABCD->rel(ABE_FG) [real paths]" );
    $cwd->child("A")->remove_tree;
    $deep->remove_tree;
    $deep->mkpath;

    # (d) symlink in path from common to new base; paths after symlink
    # don't exist
    #
    #   ABCD->rel(ABE_FGH) - common point AB -  result depends on E_F resolution
    #
    $path = $cwd->child("A/B/C/D");
    $path->mkpath;
    $cwd->child("A/B/E")->mkpath;
    symlink $deep, "A/B/E/F" or die $!;
    $base   = $cwd->child("A/B/E/F/G/H");
    $expect = $path->relative( $deep->child("G/H") );
    is( $path->relative($base), $expect, "ABCD->rel(ABE_FGH) [unreal paths]" );
    $cwd->child("A")->remove_tree;
    $deep->remove_tree;
    $deep->mkpath;

    # (e) symlink at end of common, with updir at start of new base
    #
    #   AB_CDE->rel(AB_C..FG) - common point really AB - result depends on
    #   symlink resolution
    #
    $cwd->child("A/B")->mkpath;
    symlink $deep, "A/B/C" or die "$!";
    $path = $cwd->child("A/B/C/D/E");
    $path->mkpath;
    $base = $cwd->child("A/B/C/../F/G");
    $base->mkpath;
    $expect = $path->relative( $deep->parent->child("F/G")->realpath );
    is( $path->relative($base), $expect, "AB_CDE->rel(AB_C..FG)" );
    $cwd->child("A")->remove_tree;
    $deep->remove_tree;
    $deep->mkpath;

    # (f) updirs in new base [files exist]
    #
    #   ABCDE->rel(ABF..GH) - common point AB - result ../../C/D/E
    #
    $path = $cwd->child("A/B/C/D/E");
    $path->mkpath;
    $cwd->child("A/B/F")->mkpath;
    $cwd->child("A/B/G/H")->mkpath;
    $base   = $cwd->child("A/B/F/../G/H");
    $expect = "../../C/D/E";
    is( $path->relative($base), $expect, "ABCDE->rel(ABF..GH) [real paths]" );
    $cwd->child("A")->remove_tree;

    # (f) updirs in new base [files don't exist]
    #
    #   ABCDE->rel(ABF..GH) - common point AB - result ../../C/D/E
    #
    $path   = $cwd->child("A/B/C/D/E");
    $base   = $cwd->child("A/B/F/../G/H");
    $expect = "../../C/D/E";
    is( $path->relative($base), $expect, "ABCDE->rel(ABF..GH) [unreal paths]" );
    $cwd->child("A")->remove_tree;

};

# XXX need to test common prefix case where both are abs but one
# has volume and one doesn't. (Win32: UNC and drive letters)

# XXX need to test A->rel(B) where A and B are different volumes,
# including UNC and drive letters

done_testing;
# COPYRIGHT
