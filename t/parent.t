use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

plan skip_all => "Not ready for Win32 yet"
  if $^O eq 'MSWin32';

use Path::Class;
use Path::Tiny;

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
            my $parent = shift @$list;
            is( $path->parent, $parent, "$path -> $parent" );
##            is( dir("$path")->parent, $parent, "Path::Class agrees" );
            $path = path($parent);
        }
    };
}

done_testing;
# COPYRIGHT
