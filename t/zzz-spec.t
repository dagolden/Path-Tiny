use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;
use Cwd;

my $IS_WIN32 = $^O eq 'MSWin32';

# tests adapted from File::Spec's t/Spec.t test

# Each element in this array is a single test. Storing them this way makes
# maintenance easy, and should be OK since perl should be pretty functional
# before these tests are run.

# the third column has Win32 specific alternative output; this appears to be
# collapsing of foo/../bar type structures since Win32 has no symlinks and
# doesn't need to keep the '..' part. -- xdg, 2013-01-30

my @tests = (
    # [ Function          ,            Expected          ,         Win32-different ]

    [ "path('a','b','c')",                           'a/b/c' ],
    [ "path('a','b','./c')",                         'a/b/c' ],
    [ "path('./a','b','c')",                         'a/b/c' ],
    [ "path('c')",                                   'c' ],
    [ "path('./c')",                                 'c' ],
    [ "path('/')",                                   '/' ],
    [ "path('d1','d2','d3')",                        'd1/d2/d3' ],
    [ "path('/','d2/d3')",                           '/d2/d3' ],
    [ "path('/.')",                                  '/' ],
    [ "path('/./')",                                 '/' ],
    [ "path('/a/./')",                               '/a' ],
    [ "path('/a/.')",                                '/a' ],
    [ "path('/../../')",                             '/' ],
    [ "path('/../..')",                              '/' ],
    [ "path('/t1/t2/t4')->relative('/t1/t2/t3')",    '../t4' ],
    [ "path('/t1/t2')->relative('/t1/t2/t3')",       '..' ],
    [ "path('/t1/t2/t3/t4')->relative('/t1/t2/t3')", 't4' ],
    [ "path('/t4/t5/t6')->relative('/t1/t2/t3')",    '../../../t4/t5/t6' ],
    [ "path('/')->relative('/t1/t2/t3')",            '../../..' ],
    [ "path('///')->relative('/t1/t2/t3')",          '../../..' ],
    [ "path('/.')->relative('/t1/t2/t3')",           '../../..' ],
    [ "path('/./')->relative('/t1/t2/t3')",          '../../..' ],
    [ "path('/t1/t2/t3')->relative( '/')",           't1/t2/t3' ],
    [ "path('/t1/t2/t3')->relative( '/t1')",         't2/t3' ],
    [ "path('t1/t2/t3')->relative( 't1')",           't2/t3' ],
    [ "path('t1/t2/t3')->relative( 't4')",           '../t1/t2/t3' ],
    [ "path('.')->relative( '.')",                   '.' ],
    [ "path('/')->relative( '/')",                   '.' ],
    [ "path('../t1')->relative( 't2/t3')",           '../../../t1' ],
    [ "path('t1')->relative( 't2/../t3')",           '../t1' ],
    [ "path('t4')->absolute('/t1/t2/t3')",           '/t1/t2/t3/t4' ],
    [ "path('t4/t5')->absolute('/t1/t2/t3')",        '/t1/t2/t3/t4/t5' ],
    [ "path('.')->absolute('/t1/t2/t3')",            '/t1/t2/t3' ],
    [ "path('///../../..//./././a//b/.././c/././')", '/a/b/../c',       '/a/c' ],
    [ "path('a/../../b/c')",                         'a/../../b/c',     '../b/c' ],
    [ "path('..')->absolute('/t1/t2/t3')",           '/t1/t2/t3/..',    '/t1/t2' ],
    [ "path('../t4')->absolute('/t1/t2/t3')",        '/t1/t2/t3/../t4', '/t1/t2/t4' ],
    # need to wash through rootdir->absolute->child to pick up volume on Windows
    [ "path('/t1')->absolute('/t1/t2/t3')", Path::Tiny->rootdir->absolute->child("t1") ],
);

my @win32_tests;

# this is lazy so we don't invoke any calls unless we're on Windows
if ($IS_WIN32) {
    @win32_tests = (
        [ "path('/')",               '/' ],
        [ "path('/', '../')",        '/' ],
        [ "path('/', '..\\')",       '/' ],
        [ "path('\\', '../')",       '/' ],
        [ "path('\\', '..\\')",      '/' ],
        [ "path('\\d1\\','d2')",     '/d1/d2' ],
        [ "path('\\d1','d2')",       '/d1/d2' ],
        [ "path('\\d1','\\d2')",     '/d1/d2' ],
        [ "path('\\d1','\\d2\\')",   '/d1/d2' ],
        [ "path('d1','d2','d3')",    'd1/d2/d3' ],
        [ "path('\\', 'foo')",       '/foo' ],
        [ "path('a','b','c')",       'a/b/c' ],
        [ "path('a','b','.\\c')",    'a/b/c' ],
        [ "path('.\\a','b','c')",    'a/b/c' ],
        [ "path('c')",               'c' ],
        [ "path('.\\c')",            'c' ],
        [ "path('a/..','../b')",     '../b' ],
        [ "path('a\\..\\..\\b\\c')", '../b/c' ],
        [ "path('//a\\b//c')",       '//a/b/c' ],
        [ "path('/a/..../c')",       '/a/..../c' ],
        [ "path('//a/b\\c')",        '//a/b/c' ],
        [ "path('////')",            '/' ],
        [ "path('//')",              '/' ],
        [ "path('/.')",              '/' ],
        [ "path('//a/b/../../c')",   '//a/b/c' ],
        [ "path('//a/b/c/../d')",    '//a/b/d' ],
        [ "path('//a/b/c/../../d')", '//a/b/d' ],
        [ "path('/a/b/c/../../d')",  '/a/d' ],
        [ "path('\\../temp\\')",     '/temp' ],
        [ "path('\\../')",           '/' ],
        [ "path('\\..\\')",          '/' ],
        [ "path('/../')",            '/' ],
        [ "path('/../')",            '/' ],
        [ "path('d1/../foo')",       'foo' ],
        # if there's no C drive, getdcwd will probably return '', so fake it
        [ "path('C:')", path( eval { Cwd::getdcwd("C:") } || "C:/" ) ],
        [ "path('\\\\server\\share\\')", '//server/share/' ],
        [ "path('\\\\server\\share')",   '//server/share/' ],
        [ "path('//server/share/')",     '//server/share/' ],
        [ "path('//server/share')",      '//server/share/' ],
        [ "path('//d1','d2')",           '//d1/d2/' ],
    );
    # These test require no "A:" drive mapped
    my $drive_a_cwd = Cwd::getdcwd("A:");
    $drive_a_cwd = "" unless defined $drive_a_cwd;
    if ( $drive_a_cwd eq "" ) {
        push @win32_tests,
          [ "path('A:/d1','d2','d3')", 'A:/d1/d2/d3' ],
          [ "path('A:/')",             'A:/' ],
          [ "path('A:', 'foo')",       'A:/foo' ],
          [ "path('A:', 'foo')",       'A:/foo' ],
          [ "path('A:f')",             'A:/f' ],
          [ "path('A:/')",             'A:/' ],
          [ "path('a:/')",             'A:/' ],;
    }
}

# Tries a named function with the given args and compares the result against
# an expected result. Works with functions that return scalars or arrays.
for ( @tests, $IS_WIN32 ? @win32_tests : () ) {
    my ( $function, $expected, $win32case ) = @$_;
    $expected = $win32case if $IS_WIN32 && $win32case;

    $function =~ s#\\#\\\\#g;
    my $got = join ',', eval $function;

    if ($@) {
        is( $@, '', $function );
    }
    else {
        is( $got, $expected, $function );
    }
}

done_testing;
# COPYRIGHT
