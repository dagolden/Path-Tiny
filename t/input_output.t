use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::Deep '!blessed';
use File::Spec::Unix;

use Path::Tiny;

my $tmp = Path::Tiny->tempdir;

sub _lines {
    return ( "Line1\n", "Line2\n" );
}

sub _utf8_lines {
    my $line3 = "\302\261\n";
    utf8::decode($line3);
    return ( _lines(), $line3 );
}

subtest "spew -> slurp" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "spew -> slurp (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    is( $file->slurp_utf8, join( '', _utf8_lines ), "slurp" );
};

subtest "spew -> lines" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    is( join( '', $file->lines ), join( '', _lines ), "lines" );
};

subtest "spew -> lines (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    is( join( '', $file->lines_utf8 ), join( '', _utf8_lines ), "lines" );
};

subtest "spew -> lines (count)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    my @exp = _lines;
    is( join( '', $file->lines( { count => 2 } ) ), join( '', @exp[ 0 .. 1 ] ),
        "lines" );
};

subtest "spew -> lines (count, UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    my @exp = _utf8_lines;
    is( join( '', $file->lines_utf8( { count => 3 } ) ), join( '', @exp ),
        "lines" );
};

subtest "append -> slurp" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append(_lines), "append" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "append -> slurp (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append_utf8(_utf8_lines), "append" );
    is( $file->slurp_utf8, join( '', _utf8_lines ), "slurp" );
};

subtest "openw -> openr" => sub {
    my $file = Path::Tiny->tempfile;
    {
        my $fh = $file->openw;
        ok( ( print {$fh} _lines ), "openw & print" );
    }
    {
        my $fh = $file->openr;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _lines ), "openr & read" );
    }
};

subtest "openw -> openr (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    {
        my $fh = $file->openw_utf8;
        ok( ( print {$fh} _utf8_lines ), "openw & print" );
    }
    {
        my $fh = $file->openr_utf8;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _utf8_lines ), "openr & read" );
    }
};

subtest "opena -> openr" => sub {
    my $file  = Path::Tiny->tempfile;
    my @lines = _lines;
    {
        my $fh = $file->openw;
        ok( ( print {$fh} shift @lines ), "openw & print one line" );
    }
    {
        my $fh = $file->opena;
        ok( ( print {$fh} @lines ), "opena & print rest of lines" );
    }
    {
        my $fh = $file->openr;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _lines ), "openr & read" );
    }
};

subtest "opena -> openr (UTF-8)" => sub {
    my $file  = Path::Tiny->tempfile;
    my @lines = _utf8_lines;
    {
        my $fh = $file->openw_utf8;
        ok( ( print {$fh} shift @lines ), "openw & print one line" );
    }
    {
        my $fh = $file->opena_utf8;
        ok( ( print {$fh} @lines ), "opena & print rest of lines" );
    }
    {
        my $fh = $file->openr_utf8;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _utf8_lines ), "openr & read" );
    }
};

subtest "openrw" => sub {
    my $file = Path::Tiny->tempfile;
    my $fh   = $file->openrw;
    ok( ( print {$fh} _lines ), "openrw & print" );
    ok( seek( $fh, 0, 0 ), "seek back to start" );
    my $got = do { local $/, <$fh> };
    is( $got, join( '', _lines ), "openr & read" );
};

subtest "openrw (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    my $fh   = $file->openrw;
    ok( ( print {$fh} _utf8_lines ), "openrw & print" );
    ok( seek( $fh, 0, 0 ), "seek back to start" );
    my $got = do { local $/, <$fh> };
    is( $got, join( '', _utf8_lines ), "openr & read" );
};

done_testing;
# COPYRIGHT
