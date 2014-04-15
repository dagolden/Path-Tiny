use 5.008001;
use strict;
use warnings;
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

subtest "temp files not cleaned up until all clones are gone" => sub {
    my $temp  = Path::Tiny->tempfile;
    my $clone = path($temp);

    my $file = $temp->stringify;
    ok -e $file;
    $temp = undef;
    ok -e $file;
    $clone = undef;
    ok !-e $file;
};

done_testing;
# COPYRIGHT
