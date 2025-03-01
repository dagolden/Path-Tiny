use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Temp ();

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;

my $tempdir = File::Temp->newdir;

my $path = path($tempdir)->child("foo");

ok( !-e $path,     "target directory not created yet" );
ok( $path->mkpath, "mkpath on directory returned true" );
ok( -d $path,      "target directory created" );

if ( $^O ne 'MSWin32' ) {
    my $path2 = path($tempdir)->child("bar");
    ok( !-e $path2, "target directory not created yet" );
    ok( $path2->mkpath( { mode => 0700 } ), "mkpath on directory with mode" );
    if ( $^O ne 'msys' ) {
        is( $path2->stat->mode & 0777, 0700, "correct mode" );
    }
    ok( -d $path2, "target directory created" );
}

{
    for my $weird_args (
        ["bogus"],  # a string, somebody thought it's the child name
        [mode=>1],  # programmer forgot to wrap pairs in {...}
        [{}, 1 ],   # valid {} but extra argument; oops!
        [[]],       # weird mistake, but better to die than ignore
    ) {
        my $error = exception { $path->mkpath(@$weird_args) };
        like(
          $error,
          qr/method argument was given, but was not a hash reference/,
          "passing a weird argument to ->mkpath throws (@$weird_args)",
        );
    }
}

done_testing;
# COPYRIGHT
