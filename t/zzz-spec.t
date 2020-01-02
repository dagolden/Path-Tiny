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
    if ( Cwd::getdcwd("A:") eq '' ) {
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

# XXX not sure how to adapt this sanely for use with Path::Tiny testing, so
# I'll punt for now

##
### FakeWin32 subclass (see below) just sets CWD to C:\one\two and getdcwd('D') to D:\alpha\beta
##
##[ "FakeWin32->abs2rel('/t1/t2/t3','/t1/t2/t3')",     '.'                      ],
##[ "FakeWin32->abs2rel('/t1/t2/t4','/t1/t2/t3')",     '..\\t4'                 ],
##[ "FakeWin32->abs2rel('/t1/t2','/t1/t2/t3')",        '..'                     ],
##[ "FakeWin32->abs2rel('/t1/t2/t3/t4','/t1/t2/t3')",  't4'                     ],
##[ "FakeWin32->abs2rel('/t4/t5/t6','/t1/t2/t3')",     '..\\..\\..\\t4\\t5\\t6' ],
##[ "FakeWin32->abs2rel('../t4','/t1/t2/t3')",         '..\\..\\..\\one\\t4'    ],  # Uses _cwd()
##[ "FakeWin32->abs2rel('/','/t1/t2/t3')",             '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('///','/t1/t2/t3')",           '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('/.','/t1/t2/t3')",            '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('/./','/t1/t2/t3')",           '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('\\\\a/t1/t2/t4','/t2/t3')",   '\\\\a\\t1\\t2\\t4'      ],
##[ "FakeWin32->abs2rel('//a/t1/t2/t4','/t2/t3')",     '\\\\a\\t1\\t2\\t4'      ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3','A:/t1/t2/t3')",     '.'                  ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3/t4','A:/t1/t2/t3')",  't4'                 ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3','A:/t1/t2/t3/t4')",  '..'                 ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3','B:/t1/t2/t3')",     'A:\\t1\\t2\\t3'     ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3/t4','B:/t1/t2/t3')",  'A:\\t1\\t2\\t3\\t4' ],
##[ "FakeWin32->abs2rel('E:/foo/bar/baz')",            'E:\\foo\\bar\\baz'      ],
##[ "FakeWin32->abs2rel('C:/one/two/three')",          'three'                  ],
##[ "FakeWin32->abs2rel('C:\\Windows\\System32', 'C:\\')",  'Windows\System32'  ],
##[ "FakeWin32->abs2rel('\\\\computer2\\share3\\foo.txt', '\\\\computer2\\share3')",  'foo.txt' ],
##[ "FakeWin32->abs2rel('C:\\one\\two\\t\\asd1\\', 't\\asd\\')", '..\\asd1'     ],
##[ "FakeWin32->abs2rel('\\one\\two', 'A:\\foo')",     'C:\\one\\two'           ],
##
##[ "FakeWin32->rel2abs('temp','C:/')",                       'C:\\temp'                        ],
##[ "FakeWin32->rel2abs('temp','C:/a')",                      'C:\\a\\temp'                     ],
##[ "FakeWin32->rel2abs('temp','C:/a/')",                     'C:\\a\\temp'                     ],
##[ "FakeWin32->rel2abs('../','C:/')",                        'C:\\'                            ],
##[ "FakeWin32->rel2abs('../','C:/a')",                       'C:\\'                            ],
##[ "FakeWin32->rel2abs('\\foo','C:/a')",                     'C:\\foo'                         ],
##[ "FakeWin32->rel2abs('temp','//prague_main/work/')",       '\\\\prague_main\\work\\temp'     ],
##[ "FakeWin32->rel2abs('../temp','//prague_main/work/')",    '\\\\prague_main\\work\\temp'     ],
##[ "FakeWin32->rel2abs('temp','//prague_main/work')",        '\\\\prague_main\\work\\temp'     ],
##[ "FakeWin32->rel2abs('../','//prague_main/work')",         '\\\\prague_main\\work'           ],
##[ "FakeWin32->rel2abs('D:foo.txt')",                        'D:\\alpha\\beta\\foo.txt'        ],

##
##can_ok('File::Spec::Win32', '_cwd');
##
##{
##    package File::Spec::FakeWin32;
##    use vars qw(@ISA);
##    @ISA = qw(File::Spec::Win32);
##
##    sub _cwd { 'C:\\one\\two' }
##
##    # Some funky stuff to override Cwd::getdcwd() for testing purposes,
##    # in the limited scope of the rel2abs() method.
##    if ($Cwd::VERSION && $Cwd::VERSION gt '2.17') {  # Avoid a 'used only once' warning
##  local $^W;
##      *rel2abs = sub {
##          my $self = shift;
##          local $^W;
##          local *Cwd::getdcwd = sub {
##            return 'D:\alpha\beta' if $_[0] eq 'D:';
##            return 'C:\one\two'    if $_[0] eq 'C:';
##            return;
##          };
##          *Cwd::getdcwd = *Cwd::getdcwd; # Avoid a 'used only once' warning
##          return $self->SUPER::rel2abs(@_);
##      };
##      *rel2abs = *rel2abs; # Avoid a 'used only once' warning
##    }
##}

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
