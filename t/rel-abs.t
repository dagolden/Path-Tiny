use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

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
# and lower case 'a', 'b' denotes relative paths.  When there are multiple
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
        path( "..", $cwd, "foo/bar" ),
        "a->rel(B) from tmpdir"
    );

}

# XXX need to test symlink cases on absolute paths with common roots:
#
# (a) symlink in common path
#
#   A_BCD->rel(A_BEF) - common point A_BC - result: ../../C/D
#
# (b) symlink in path from common to original path
#
#   ABC_DE->rel(ABFG) - common point AB - result: ../../C/D/E
#
# (c) symlink in path from common to new base
#
#   ABCD->rel(ABE_FG) - common point AB -  result depends on E_F resolution

# XXX need to test common prefix case where both are abs but one
# has volume and one doesn't. (Win32: UNC and drive letters)

# XXX need to test A->rel(B) where A and B are different volumes,
# including UNC and drive letters

##subtest "A->rel(A)" => sub {
##    my $wd   = tempd;
##    my $deep = path("one/two/three");
##    $deep->mkpath;
##    eval { symlink $deep, "link" };
##    plan skip_all => "No symlink support"
##      if $@;
##
##    my $orig          = $deep->child("four/five");
##    my $symlink_child = path("link")->absolute->child("four/five");
##
##    is( $symlink_child->relative( $deep->absolute ),
##        "four/five", "short symlink path relative to longer absolute real path" );
##};
##
done_testing;
# COPYRIGHT
