use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;
use Cwd;

my $IS_WIN32 = $^O eq 'MSWin32';

my @cases = (
    # path1 => path2 => path1->subsumes(path2)

    "identity always subsumes" => [
        [ '.'     => '.'     => 1 ],
        [ '/'     => '/'     => 1 ],
        [ '..'    => '..'    => 1 ],
        [ '../..' => '../..' => 1 ],
        [ '/foo/' => '/foo'  => 1 ],
        [ 'foo/'  => 'foo'   => 1 ],
        [ './foo' => 'foo'   => 1 ],
        [ 'foo/.' => 'foo'   => 1 ],
    ],

    "absolute v. absolute" => [
        [ '/foo'     => '/foo/bar'      => 1 ],
        [ '/foo'     => '/foo/bar/baz'  => 1 ],
        [ '/foo'     => '/foo/bar/baz/' => 1 ],
        [ '/'        => '/foo'          => 1 ],
        [ '/foo'     => '/bar'          => 0 ],
        [ '/foo/bar' => '/foo/baz'      => 0 ],
    ],

    "relative v. relative" => [
        [ '.'         => 'foo'         => 1 ],
        [ 'foo'       => 'foo/baz'     => 1 ],
        [ './foo/bar' => 'foo/bar/baz' => 1 ],
        [ './foo/bar' => './foo/bar'   => 1 ],
        [ './foo/bar' => 'foo/bar'     => 1 ],
        [ 'foo/bar'   => './foo/bar'   => 1 ],
        [ 'foo/bar'   => 'foo/baz'     => 0 ],
    ],

    "relative v. absolute" => [
        [ path(".")->absolute  => 't'                 => 1 ],
        [ "."                  => path('t')->absolute => 1 ],
        [ "foo"                => path('t')->absolute => 0 ],
        [ path("..")->realpath => 't'                 => 1 ],
        [ path("lib")->absolute => 't'                => 0 ],
    ],

    "updirs in paths" => [
        [ '/foo'        => '/foo/bar/baz/..' => 1 ],
        [ '/foo/bar'    => '/foo/bar/../baz' => $IS_WIN32 ? 0 : 1 ],
        [ '/foo/../bar' => '/bar'            => $IS_WIN32 ? 1 : 0 ],
        [ '..'          => '../bar'          => 1 ],
    ],

);

if ( $IS_WIN32 ) {
    my $vol = path(Cwd::getdcwd())->volume . "/";
    my $other = $vol ne 'Z:/' ? 'Z:/' : 'Y:/';
    push @cases, 'Win32 cases',
      [
        [ "C:/foo"     => "C:/foo" => 1 ],
        [ "C:/foo"     => "C:/bar" => 0 ],
        [ "C:/"        => "C:/foo" => 1 ],
        [ "C:/"        => "D:/"    => 0 ],
        [ "${vol}foo"  => "/foo"   => 1 ],
        [ $vol         => "/foo"   => 1 ],
        [ $vol         => $other   => 0 ],
        [ "/"          => $vol     => 1 ],
        [ "/"          => $other   => 0 ],
        [ "/foo"       => "${vol}foo"     => 1 ],
      ];
}

while (@cases) {
    my ( $subtest, $tests ) = splice( @cases, 0, 2 );
    subtest $subtest => sub {
        for my $t (@$tests) {
            my ( $path1, $path2, $subsumes ) = @$t;
            my $label =
              join( " ", $path1, ( $subsumes ? "subsumes" : "does not subsume" ), $path2 );
            ok( !!path($path1)->subsumes($path2) eq !!$subsumes, $label )
              or diag "PATH 1:\n", explain( path($path1) ), "\nPATH2:\n",
              explain( path($path2) );
        }
    };
}

done_testing;
# COPYRIGHT
