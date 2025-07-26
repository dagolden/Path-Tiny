use 5.008001;
use strict;
use warnings;
use Cwd; # hack around https://bugs.activestate.com/show_bug.cgi?id=104767
use Test::More 0.96;
use File::Spec::Unix;

use lib 't/lib';
use TestUtils qw/exception tempd/;

use Path::Tiny;

subtest "tempdir" => sub {
    my $tempdir = Path::Tiny->tempdir;
    isa_ok( $tempdir->cached_temp, 'File::Temp::Dir', "cached_temp" );
    my $string = $tempdir->stringify;
    ok( $tempdir->exists, "tempdir exists" );
    undef $tempdir;
    ok( !-e $string, "tempdir destroyed" );
};

subtest "tempfile" => sub {
    my $tempfile = Path::Tiny->tempfile;
    isa_ok( $tempfile->cached_temp, 'File::Temp', "cached_temp" );
    my $string = $tempfile->stringify;
    ok( $tempfile->exists, "tempfile exists" );
    undef $tempfile;
    ok( !-e $string, "tempfile destroyed" );
};

subtest "tempdir w/ TEMPLATE" => sub {
    my $tempdir = Path::Tiny->tempdir( TEMPLATE => "helloXXXXX" );
    like( $tempdir, qr/hello/, "found template" );
};

subtest "tempfile w/ TEMPLATE" => sub {
    my $tempfile = Path::Tiny->tempfile( TEMPLATE => "helloXXXXX" );
    like( $tempfile, qr/hello/, "found template" );
};

subtest "tempdir w/ leading template" => sub {
    my $tempdir = Path::Tiny->tempdir("helloXXXXX");
    like( $tempdir, qr/hello/, "found template" );
};

subtest "tempfile w/ leading template" => sub {
    my $tempfile = Path::Tiny->tempfile("helloXXXXX");
    like( $tempfile, qr/hello/, "found template" );
};

subtest "tempfile handle" => sub {
    my $tempfile = Path::Tiny->tempfile;
    my $fh       = $tempfile->filehandle;
    is( ref $tempfile->[5],    'File::Temp', "cached File::Temp object" );
    is( fileno $tempfile->[5], undef,        "cached handle is closed" );
};

subtest "survives absolute" => sub {
    my $wd = tempd;
    my $tempdir = Path::Tiny->tempdir( DIR => '.' )->absolute;
    ok( -d $tempdir, "exists" );
};

subtest "realpath option" => sub {
    my $wd = tempd;

    my $tempdir = Path::Tiny->tempdir( { realpath => 1 }, DIR => '.' );
    is( $tempdir, $tempdir->realpath, "tempdir has realpath" );

    my $tempfile = Path::Tiny->tempfile( { realpath => 1 }, DIR => '.' );
    is( $tempfile, $tempfile->realpath, "tempfile has realpath" );
};

subtest "cached_temp on non tempfile" => sub {
    my $path = path("abcdefg");
    eval { $path->cached_temp };
    like( $@, qr/has no cached File::Temp object/, "cached_temp error message" );
};

subtest "tempdir w/ leading template as instance method" => sub {
    my $wd = tempd;

    my $basedir = Path::Tiny->cwd;
    my $repodir = $basedir->child('whatever');
    $repodir->remove_tree if $repodir->exists;
    $repodir->mkdir;
    my $tempdir = $repodir->tempdir("helloXXXXX");
    like( $tempdir, qr/hello/, "found template" );
    ok( scalar($repodir->children) > 0, 'something was created' );
    my $basename = $tempdir->basename;
    ok( -d $repodir->child($basename), "right directory exists" );
};

subtest "tempdir w/ leading template as instance method" => sub {
    my $wd = tempd;

    my $basedir = Path::Tiny->cwd;
    my $repodir = $basedir->child('whatever');
    $repodir->remove_tree if $repodir->exists;
    $repodir->mkdir;
    my $tempdir = $repodir->tempdir("helloXXXXX");
    like( $tempdir, qr/hello/, "found template" );
    ok( scalar($repodir->children) > 0, 'something was created' );
    my $basename = $tempdir->basename;
    ok( -d $repodir->child($basename), "right directory exists" );
};

subtest "tempfile w/out leading template as instance method" => sub {
    my $wd = tempd;

    my $basedir = Path::Tiny->cwd;
    my $repodir = $basedir->child('whatever');
    $repodir->remove_tree if $repodir->exists;
    $repodir->mkdir;
    my $tempfile = $repodir->tempfile( TEMPLATE => "helloXXXXX" );
    like( $tempfile, qr/hello/, "found template" );
    ok( scalar($repodir->children) > 0, 'something was created' );
    my $basename = $tempfile->basename;
    ok( -e $repodir->child($basename), "right file exists" );
};

subtest "tempfile w/out leading template as instance method" => sub {
    my $wd = tempd;

    my $basedir = Path::Tiny->cwd;
    my $repodir = $basedir->child('whatever');
    $repodir->remove_tree if $repodir->exists;
    $repodir->mkdir;
    my $tempfile = $repodir->tempfile( TEMPLATE => "helloXXXXX");
    like( $tempfile, qr/hello/, "found template" );
    ok( scalar($repodir->children) > 0, 'something was created' );
    my $basename = $tempfile->basename;
    ok( -e $repodir->child($basename), "right file exists" );
};

subtest "tempfile, instance method, overridden DIR" => sub {
    my $wd = tempd;

    my $basedir = Path::Tiny->cwd;
    my $repodir = $basedir->child('whatever');
    $repodir->remove_tree if $repodir->exists;
    $repodir->mkdir;
    my $bd = $basedir->stringify;
    my $tempfile = $repodir->tempfile("helloXXXXX", DIR => $bd);
    ok( $tempfile->parent ne $bd ), "DIR is overridden";
};

subtest "is_temporary" => sub {
    my $tempdir = Path::Tiny->tempdir;
    ok( $tempdir->is_temporary, "tempdir is temporary" );
    my $tempfile = Path::Tiny->tempfile;
    ok( $tempfile->is_temporary, "tempfile is temporary" );
    my $path = path("abcdefg");
    ok( !$path->is_temporary, "regular path is not temporary" );
};

done_testing;
# COPYRIGHT
