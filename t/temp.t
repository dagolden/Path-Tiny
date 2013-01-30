use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Deep '!blessed';
use File::Spec::Unix;

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

subtest "tempfile handle" => sub {
    my $tempfile = Path::Tiny->tempfile;
    my $fh       = $tempfile->filehandle;
    is( $fh, $tempfile->[4], "filehandle() returns cached File::Temp object" );
    unlike( PerlIO::get_layers($fh), qr/:utf8/, "handle does not have utf8" );
    ok( $fh = $tempfile->filehandle( ">", ":utf8" ), "calling filehandle() with :utf8" );
    like( join( ":", PerlIO::get_layers($fh) ), qr/utf8/, "handle has utf8" );
};

done_testing;
# COPYRIGHT
