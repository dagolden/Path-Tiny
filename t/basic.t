use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Spec;
use Path::Tiny;
use Cwd;

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
    my ($homedir) = glob('~');
    my $dir = path('~');
    is( $dir, $homedir, 'Test my homedir' );
    $dir = path('~/');
    is( $dir, $homedir, 'Test my homedir with trailing "/"' );
    $dir = path('~/foo/bar');
    is( $dir, $homedir . '/foo/bar', 'Test my homedir with longer path' );
    $dir = path('~/foo/bar/');
    is( $dir, $homedir . '/foo/bar', 'Test my homedir, longer path and trailing "/"' );

    my ($root_homedir) = glob('~root');
    $dir = path('~root');
    is( $dir, $root_homedir, 'Test root homedir' );
    $dir = path('~root');
    is( $dir, $root_homedir, 'Test root homedir with trailing /' );
    $dir = path('~root/foo/bar');
    is( $dir, $root_homedir . '/foo/bar', 'Test root homedir with longer path' );
    $dir = path('~root/foo/bar/');
    is(
        $dir,
        $root_homedir . '/foo/bar',
        'Test root homedir, longer path and trailing "/"'
    );

    my ($missing_homedir) = glob('~idontthinkso');
    $dir = path('~idontthinkso');
    is( $dir, '~idontthinkso',  'Test homedir of nonexistant user' );
    is( $dir, $missing_homedir, 'Test homedir of nonexistant user (via glob)' );
}

# freeze/thaw
{
    my $path = path("/foo/bar/baz");
    is( Path::Tiny->THAW( "fake", $path->FREEZE("fake") ),
        $path, "FREEZE-THAW roundtrip" );
}

done_testing();
