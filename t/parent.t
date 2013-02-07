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
            my $expect = shift @$list;
            my $got    = $path->parent;
            is( $got, canonical($expect), "$path -> $got" );
            is( dir("$path")->parent, canonpath($expect), "Path::Class agrees" ) if $DEBUG;
            $path = $got;
        }
    };
}

done_testing;
# COPYRIGHT
