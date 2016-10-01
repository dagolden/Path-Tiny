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
    my $string  = $tempdir->stringify;
    ok( $tempdir->exists, "tempdir exists" );
    undef $tempdir;
    ok( !-e $string, "tempdir destroyed" );
};

subtest "tempfile" => sub {
    my $tempfile = Path::Tiny->tempfile;
    my $string   = $tempfile->stringify;
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

done_testing;
# COPYRIGHT
