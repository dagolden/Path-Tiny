use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Spec;
use File::Glob;
use Path::Tiny;
use Cwd;

my $IS_WIN32 = $^O eq 'MSWin32';
my $IS_CYGWIN = $^O eq 'cygwin';

use lib 't/lib';
use TestUtils qw/exception/;

my $file1 = path('foo.txt');
isa_ok( $file1, "Path::Tiny" );
ok $file1->isa('Path::Tiny');
is $file1, 'foo.txt';
ok $file1->is_relative;
is $file1->dirname,  '.';
is $file1->basename, 'foo.txt';

my $file2 = path( 'dir', 'bar.txt' );
is $file2, 'dir/bar.txt';
ok !$file2->is_absolute;
is $file2->dirname,  'dir/';
is $file2->basename, 'bar.txt';

my $dir = path('tmp');
is $dir, 'tmp';
ok !$dir->is_absolute;
is $dir->basename, 'tmp';

my $dir2 = path('/tmp');
is $dir2, '/tmp';
ok $dir2->is_absolute;

my $cat = path( $dir, 'foo' );
is $cat, 'tmp/foo';
$cat = $dir->child('foo');
is $cat, 'tmp/foo';
is $cat->dirname,  'tmp/';
is $cat->basename, 'foo';

$cat = path( $dir2, 'foo' );
is $cat, '/tmp/foo';
$cat = $dir2->child('foo');
is $cat,     '/tmp/foo';
isa_ok $cat, 'Path::Tiny';
is $cat->dirname, '/tmp/';

$cat = $dir2->child('foo');
is $cat,     '/tmp/foo';
isa_ok $cat, 'Path::Tiny';
is $cat->basename, 'foo';

my $sib = $cat->sibling('bar');
is $sib,     '/tmp/bar';
isa_ok $sib, 'Path::Tiny';

my $file = path('/foo//baz/./foo');
is $file, '/foo/baz/foo';
is $file->dirname, '/foo/baz/';
is $file->parent,  '/foo/baz';

{
    my $file = path("foo/bar/baz");
    is( $file->canonpath, File::Spec->canonpath("$file"), "canonpath" );
}

{
    my $dir = path('/foo/bar/baz');
    is $dir->parent, '/foo/bar';
    is $dir->parent->parent, '/foo';
    is $dir->parent->parent->parent, '/';
    is $dir->parent->parent->parent->parent, '/';

    $dir = path('foo/bar/baz');
    is $dir->parent, 'foo/bar';
    is $dir->parent->parent, 'foo';
    is $dir->parent->parent->parent, '.';
    is $dir->parent->parent->parent->parent, '..';
    is $dir->parent->parent->parent->parent->parent, '../..';
}

{
    my $dir = path("foo/");
    is $dir, 'foo';
    is $dir->parent, '.';
}

{
    # Special cases
    for my $bad ( [''], [undef], [], [ '', 'var', 'tmp' ], [ 'foo', '', 'bar' ] ) {
        like( exception { path(@$bad) }, qr/positive-length/, "exception" );
    }
    is( Path::Tiny->cwd,     path( Cwd::getcwd() ) );
    is( path('.')->absolute, path( Cwd::getcwd() ) );
}

{
    my $file = path('/tmp/foo/bar.txt');
    is $file->relative('/tmp'),      'foo/bar.txt';
    is $file->relative('/tmp/foo'),  'bar.txt';
    is $file->relative('/tmp/'),     'foo/bar.txt';
    is $file->relative('/tmp/foo/'), 'bar.txt';

    $file = path('one/two/three');
    is $file->relative('one'), 'two/three';

    $file = path('/one[0/two');
    is $file->relative( '/one[0' ), 'two', 'path with regex special char';
}

{
    my $file = Path::Tiny->new( File::Spec->rootdir );
    my $root = Path::Tiny->rootdir;
    is( $file,               $root,  "rootdir is like path('/')" );
    is( $file->child("lib"), "/lib", "child of rootdir is correct" );
}

# constructor
{
    is( path(qw/foo bar baz/), Path::Tiny->new(qw/foo bar baz/), "path() vs new" );
    is( path(qw/foo bar baz/), path("foo/bar/baz"), "path(a,b,c) vs path('a/b/c')" );
}

# tilde processing
{
    # Construct expected paths manually with glob, but normalize with Path::Tiny
    # to work around windows slashes and drive case issues.  Extract the interior
    # paths with ->[0] rather than relying on stringification, which will escape
    # leading tildes.

    my $homedir = path(glob('~'))->[0];
    my $username = path($homedir)->basename;
    my $root_homedir = path(glob('~root'))->[0];
    my $missing_homedir = path(glob('~idontthinkso'))->[0];

    # remove one trailing slash from a path string, if present
    # so the result of concatenating a path that starts with a slash will be correct
    sub S ($) { ( my $p = $_[0] ) =~ s!/\z!!; $p }

    my @tests = (
      # [arg for path(), expected string (undef if eq arg for path()), test string]
        ['~',                        $homedir,                   'Test my homedir' ],
        ['~/',                       $homedir,                   'Test my homedir with trailing "/"' ],
        ['~/foo/bar',              S($homedir).'/foo/bar',       'Test my homedir with longer path' ],
        ['~/foo/bar/',             S($homedir).'/foo/bar',       'Test my homedir, longer path and trailing "/"' ],
        ['~root',                    $root_homedir,              'Test root homedir' ],
        ['~root/',                   $root_homedir,              'Test root homedir with trailing /' ],
        ['~root/foo/bar',          S($root_homedir).'/foo/bar',  'Test root homedir with longer path' ],
        ['~root/foo/bar/',         S($root_homedir).'/foo/bar',  'Test root homedir, longer path and trailing "/"'],
        ['~idontthinkso',            undef,                      'Test homedir of nonexistant user' ],
        ['~idontthinkso',            $missing_homedir,           'Test homedir of nonexistant user (via glob)' ],
        ['~blah blah',               undef,                      'Test space' ],
        ['~this is fun',             undef,                      'Test multiple spaces' ],
        ['~yikes \' apostrophe!',    undef,                      'Test spaces and embedded apostrophe' ],
        ['~hum " quote',             undef,                      'Test spaces and embedded quote' ],
        ['~hello ~there',            undef,                      'Test space-separated tildes' ],
        ["~fun\ttimes",              undef,                      'Test tab' ],
        ["~new\nline",               undef,                      'Test newline' ],
        ['~'.$username.' file',      undef,                      'Test \'~$username file\'' ],
        ['./~',                      '~',                        'Test literal tilde under current directory' ],
        ['~idontthinkso[123]',       undef,                      'Test File::Glob metacharacter ['],
        ['~idontthinkso*',           undef,                      'Test File::Glob metacharacter *'],
        ['~idontthinkso?',           undef,                      'Test File::Glob metacharacter ?'],
        ['~idontthinkso{a}',         undef,                      'Test File::Glob metacharacter {'],
    );

    if (! $IS_WIN32 && ! $IS_CYGWIN ) {
        push @tests, ['~idontthinkso\\x',      undef,                    'Test File::Glob metacharacter \\'];
    }

    for my $test (@tests) {
        my $path = path($test->[0]);
        my $internal_path = $path->[0]; # Avoid stringification adding a "./" prefix
        my $expected = defined $test->[1] ? $test->[1] : $test->[0];
        is($internal_path, $expected, $test->[2]);
        is($path, $expected =~ /^~/ ? "./$expected" : $expected, '... and its stringification');
    }

    is(path('.')->child('~')->[0], '~', 'Test indirect form of literal tilde under current directory');
    is(path('.')->child('~'), './~', '... and its stringification');

    $file = path('/tmp/foo/~root');
    is $file->relative('/tmp/foo')->[0], '~root', 'relative path begins with tilde';
    is $file->relative('/tmp/foo'), "./~root", '... and its stringification is escaped';

    # successful tilde expansion of account names with glob metacharacters is
    # actually untested so far because it would require such accounts to exist
    # so instead we wrap File::Glob::bsd_glob to mock up certain responses:
    my %mock = (
        '~i[dont]{think}so' => '/home/i[dont]{think}so',
        '~idont{think}so'   => '/home/idont{think}so',
        '~i{dont,think}so'  => '/home/i{dont,think}so',
    );
    if ( ! $IS_WIN32 && ! $IS_CYGWIN ) {
        $mock{'~i?dont*think*so?'} = '/home/i?dont*think*so?';
    }
    my $orig_bsd_glob = \&File::Glob::bsd_glob;
    my $do_brace_expansion_only = do { package File::Glob; GLOB_NOCHECK() | GLOB_BRACE() | GLOB_QUOTE() };
    sub mock_bsd_glob {
        my $dequoted = $orig_bsd_glob->( $_[0], $do_brace_expansion_only );
        $mock{ $dequoted } || goto &$orig_bsd_glob;
    }
    no warnings 'redefine'; local *File::Glob::bsd_glob = \&mock_bsd_glob;
    is(File::Glob::bsd_glob('{root}'), 'root', 'double-check of mock_bsd_glob dequoting');
    is(File::Glob::bsd_glob('~root'), $root_homedir, 'double-check of mock_bsd_glob fallback');
    for my $test (sort keys %mock) {
        is(path($test), $mock{ $test }, "tilde expansion with glob metacharacters in account name: $test");
    }
}

# freeze/thaw
{
    my @cases = qw(
        /foo/bar/baz"
        ./~root
    );

    for my $c ( @cases ) {
        my $path = path($c);
        is( Path::Tiny->THAW( "fake", $path->FREEZE("fake") ),
            $path, "FREEZE-THAW roundtrip: $c" );
    }
}

# assertions
{
    my $err = exception {
        path("aljfakdlfadks")->assert( sub { $_->exists } )
    };
    like( $err, qr/failed assertion/, "assert exists" );
    my $path;
    $err = exception {
        $path = path("t")->assert( sub { -d && -r _ } )
    };
    is( $err, '', "no exception if assertion succeeds" );
    isa_ok( $path, "Path::Tiny", "assertion return value" );

    $err = exception {
        path(".")->visit(
            sub { $_[1]->{$_} = { path => $_ } },
            { recurse => 1 },
        );
    };
    is $err, "", 'no exception';
}

done_testing();
