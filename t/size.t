use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception tempd/;

use Path::Tiny;

subtest "size API tests" => sub {
    my $wd   = tempd();
    my $path = path("1025");
    $path->spew( "A" x 1025 );
    is( $path->size,       -s $path, "size() is -s" );
    is( $path->size_human, "1.1 K",  "size_human() is 1.1 K" );
};

subtest "size_human format" => sub {
    my $wd    = tempd();
    my $base2 = path("1024");
    $base2->spew( "A" x 1024 );
    my $base10 = path("1000");
    $base10->spew( "A" x 1000 );

    is( $base2->size_human,                        "1.0 K",   "default" );
    is( $base2->size_human( { format => "ls" } ),  "1.0 K",   "explicit ls" );
    is( $base2->size_human( { format => "iec" } ), "1.0 KiB", "iec" );
    is( $base10->size_human( { format => "si" } ), "1.0 kB",  "si" );

    is( path("doesnotexist")->size_human, "", "missing file" );

    like(
        exception { $base2->size_human( { format => "fake" } ) },
        qr/Invalid format 'fake'/,
        "bad format exception"
    );

};

# The rest of the tests use the private function for size conversion
# rather than actually creating files of each size. Test cases were
# derived from actual `ls -lh` output on Ubuntu 20.04.

my $kib      = 1024;
my %ls_tests = (
    0                       => "0",
    $kib - 1                => "1023",
    $kib                    => "1.0 K",
    $kib + 1                => "1.1 K",
    int( 1.1 * $kib )       => "1.1 K",
    int( 1.1 * $kib ) + 1   => "1.2 K",
    int( 1.9 * $kib )       => "1.9 K",
    int( 1.9 * $kib ) + 1   => "2.0 K",
    9 * $kib                => "9.0 K",
    9 * $kib + 1            => "9.1 K",
    int( 9.9 * $kib )       => "9.9 K",
    int( 9.9 * $kib ) + 1   => "10 K",
    10 * $kib               => "10 K",
    10 * $kib + 1           => "11 K",
    ( $kib - 1 ) * $kib     => "1023 K",
    ( $kib - 1 ) * $kib + 1 => "1.0 M",

    $kib**2 - 1                => "1.0 M",
    $kib**2                    => "1.0 M",
    $kib**2 + 1                => "1.1 M",
    int( 1.1 * $kib**2 )       => "1.1 M",
    int( 1.1 * $kib**2 ) + 1   => "1.2 M",
    int( 1.9 * $kib**2 )       => "1.9 M",
    int( 1.9 * $kib**2 ) + 1   => "2.0 M",
    9 * $kib**2                => "9.0 M",
    9 * $kib**2 + 1            => "9.1 M",
    int( 9.9 * $kib**2 )       => "9.9 M",
    int( 9.9 * $kib**2 ) + 1   => "10 M",
    10 * $kib**2               => "10 M",
    10 * $kib**2 + 1           => "11 M",
    ( $kib - 1 ) * $kib**2     => "1023 M",
    ( $kib - 1 ) * $kib**2 + 1 => "1.0 G",
);

subtest "ls format" => sub {
    for my $k ( sort { $a <=> $b } keys %ls_tests ) {
        my $opts = Path::Tiny::_formats("ls");
        my $got  = Path::Tiny::_human_size( $k, @$opts );
        is( $got, $ls_tests{$k}, "ls: $k" );
    }
};

subtest "iec format" => sub {
    for my $k ( sort { $a <=> $b } keys %ls_tests ) {
        my $opts = Path::Tiny::_formats("iec");
        my $got  = Path::Tiny::_human_size( $k, @$opts );
        my $want = $ls_tests{$k};
        $want .= "iB" if $want =~ /[a-z]/i;
        is( $got, $want, "iec: $k" );
    }
};

my $kb       = 1000;
my %si_tests = (
    0                     => "0",
    $kb - 1               => "999",
    $kb                   => "1.0 kB",
    $kb + 1               => "1.1 kB",
    int( 1.1 * $kb )      => "1.1 kB",
    int( 1.1 * $kb ) + 1  => "1.2 kB",
    int( 1.9 * $kb )      => "1.9 kB",
    int( 1.9 * $kb ) + 1  => "2.0 kB",
    9 * $kb               => "9.0 kB",
    9 * $kb + 1           => "9.1 kB",
    int( 9.9 * $kb )      => "9.9 kB",
    int( 9.9 * $kb ) + 1  => "10 kB",
    10 * $kb              => "10 kB",
    10 * $kb + 1          => "11 kB",
    ( $kb - 1 ) * $kb     => "999 kB",
    ( $kb - 1 ) * $kb + 1 => "1.0 MB",

    $kb**2 - 1               => "1.0 MB",
    $kb**2                   => "1.0 MB",
    $kb**2 + 1               => "1.1 MB",
    int( 1.1 * $kb**2 )      => "1.1 MB",
    int( 1.1 * $kb**2 ) + 1  => "1.2 MB",
    int( 1.9 * $kb**2 )      => "1.9 MB",
    int( 1.9 * $kb**2 ) + 1  => "2.0 MB",
    9 * $kb**2               => "9.0 MB",
    9 * $kb**2 + 1           => "9.1 MB",
    int( 9.9 * $kb**2 )      => "9.9 MB",
    int( 9.9 * $kb**2 ) + 1  => "10 MB",
    10 * $kb**2              => "10 MB",
    10 * $kb**2 + 1          => "11 MB",
    ( $kb - 1 ) * $kb**2     => "999 MB",
    ( $kb - 1 ) * $kb**2 + 1 => "1.0 GB",
);

subtest "si format" => sub {
    for my $k ( sort { $a <=> $b } keys %si_tests ) {
        my $opts = Path::Tiny::_formats("si");
        my $got  = Path::Tiny::_human_size( $k, @$opts );
        is( $got, $si_tests{$k}, "si: $k" );
    }
};

done_testing;
# COPYRIGHT
