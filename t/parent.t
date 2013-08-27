use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

my $DEBUG;
BEGIN { $DEBUG = 0 }

BEGIN {
    if ($DEBUG) { require Path::Class; Path::Class->import }
}

use Path::Tiny;
use File::Spec::Functions qw/canonpath/;

sub canonical {
    my $d = canonpath(shift);
    $d =~ s{\\}{/}g;
    return $d;
}

my @cases = (
    "absolute" => [ "/foo/bar" => "/foo" => "/" => "/" ],
    "relative" =>
      [ "foo/bar/baz" => "foo/bar" => "foo" => "." => ".." => "../.." => "../../.." ],
    "absolute with .." =>
      [ "/foo/bar/../baz" => "/foo/bar/.." => "/foo/bar/../.." => "/foo/bar/../../.." ],
    "relative with .." =>
      [ "foo/bar/../baz" => "foo/bar/.." => "foo/bar/../.." => "foo/bar/../../.." ],
    "relative with leading .." => [ "../foo/bar" => "../foo" => ".." => "../.." ],
);

while (@cases) {
    my ( $label, $list ) = splice( @cases, 0, 2 );
    subtest $label => sub {
        my $path = path( shift @$list );
        while (@$list) {
            for my $i ( undef, 0, 1 .. @$list ) {
                my $n = (defined $i && $i > 0) ? $i : 1;
                my $expect = $list->[$n-1];
                my $got    = $path->parent($i);
                my $s = defined($i) ? $i : "undef";
                is( $got, canonical($expect), "parent($s): $path -> $got" );
                is( dir("$path")->parent, canonpath($expect), "Path::Class agrees" ) if $DEBUG;
            }
            $path = $path->parent;
            shift @$list;
        }
    };
}

my $path = '/foo..bar.txt';
my $expected = '/';
is(path($path)->parent, $expected, qq{parent($path): $path => $expected});
done_testing;
# COPYRIGHT
