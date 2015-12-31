use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;

my $tmp = Path::Tiny->tempdir;

sub _lines {
    return ( "Line1\r\n", "Line2\n" );
}

sub _utf8_lines {
    my $line3 = "\302\261\n";
    utf8::decode($line3);
    return ( _lines(), $line3 );
}

sub _no_end_of_newline_lines {
    return ( _lines(), "No end of newline" );
}

sub _utf8_no_end_of_newline_lines {
    return ( _utf8_lines(), "No end of newline" );
}

subtest "spew -> slurp" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "spew -> slurp (empty)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew, "spew" );
    is( $file->slurp, '', "slurp" );
};

subtest "spew -> slurp (arrayref)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew( [_lines] ), "spew" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "spew -> slurp (binmode)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew( { binmode => ":utf8" }, _utf8_lines ), "spew" );
    is( $file->slurp( { binmode => ":utf8" } ), join( '', _utf8_lines ), "slurp" );
};

subtest "spew -> slurp (open hint)" => sub {
    plan skip_all => "Needs 5.10" unless $] >= 5.010;
    use open IO => ":utf8";
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_utf8_lines), "spew" );
    my $got = $file->slurp();
    is( $got, join( '', _utf8_lines ), "slurp" );
    ok( utf8::is_utf8($got), "is UTF8" );
};

subtest "spew -> slurp (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    my $got = $file->slurp_utf8();
    is( $got, join( '', _utf8_lines ), "slurp" );
    ok( utf8::is_utf8($got), "is UTF8" );
};

subtest "spew -> slurp (raw)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_raw(_lines), "spew" );
    is( $file->slurp_raw, join( '', _lines ), "slurp" );
};

subtest "spew -> lines" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    is( join( '', $file->lines ), join( '', _lines ), "lines" );
    is( scalar $file->lines, my $cnt =()= _lines, "lines (scalar)" );
};

subtest "spew -> lines (open hint)" => sub {
    plan skip_all => "Needs 5.10" unless $] >= 5.010;
    use open IO => ":utf8";
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_utf8_lines), "spew" );
    my $got = join( '', $file->lines() );
    is( $got, join( '', _utf8_lines ), "slurp" );
    ok( utf8::is_utf8($got), "is UTF8" );
};

subtest "spew -> lines (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    my $got = join( '', $file->lines_utf8() );
    is( $got, join( '', _utf8_lines ), "slurp" );
    ok( utf8::is_utf8($got), "is UTF8" );
    is( scalar $file->lines, my $cnt =()= _utf8_lines, "lines (scalar)" );
};

subtest "spew -> lines (raw)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_raw(_lines), "spew" );
    is( join( '', $file->lines_raw ), join( '', _lines ), "lines" );
};

subtest "spew -> lines (count)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    my @exp = _lines;
    is( join( '', $file->lines( { count => 2 } ) ), join( '', @exp[ 0 .. 1 ] ),
        "lines" );
    is( join( '', $file->lines( { count => -2 } ) ),
        join( '', @exp[ 0 .. 1 ] ), "lines" );
};

subtest "spew -> lines (count, less than)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    my @exp = _lines;
    is( join( '', $file->lines( { count => 1 } ) ),  $exp[0], "lines" );
    is( join( '', $file->lines( { count => -1 } ) ), $exp[1], "lines" );
};

subtest "spew -> lines (count, more than)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    my @exp = _lines;
    is( join( '|', $file->lines( { count => 3 } ) ),  join( "|", @exp ), "lines" );
    is( join( '|', $file->lines( { count => -3 } ) ), join( "|", @exp ), "lines" );
};

subtest "spew -> lines (count, chomp)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_lines), "spew" );
    my @exp = map { s/[\r\n]+//; $_ } _lines;
    is( join( '', $file->lines( { chomp => 1, count => 2 } ) ),
        join( '', @exp[ 0 .. 1 ] ), "lines" );
    is( join( '', $file->lines( { chomp => 1, count => -2 } ) ),
        join( '', @exp[ 0 .. 1 ] ), "lines" );
};

subtest "spew -> lines (count, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_no_end_of_newline_lines), "spew" );
    my @exp = _no_end_of_newline_lines;
    is( join( '', $file->lines( { count => 3 } ) ), join( '', @exp[ 0 .. 2 ] ),
        "lines" );
    is( join( '', $file->lines( { count => -3 } ) ),
        join( '', @exp[ 0 .. 2 ] ), "lines" );
};

subtest "spew -> lines (count, less than, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_no_end_of_newline_lines), "spew" );
    my @exp = _no_end_of_newline_lines;
    is( join( '', $file->lines( { count => 1 } ) ),  $exp[0], "lines" );
    is( join( '', $file->lines( { count => -1 } ) ), $exp[2], "lines" );
};

subtest "spew -> lines (count, more than, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_no_end_of_newline_lines), "spew" );
    my @exp = _no_end_of_newline_lines;
    is( join( '|', $file->lines( { count => 4 } ) ),  join( "|", @exp ), "lines" );
    is( join( '|', $file->lines( { count => -4 } ) ), join( "|", @exp ), "lines" );
};

subtest "spew -> lines (count, chomp, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew(_no_end_of_newline_lines), "spew" );
    my @exp = map { s/[\r\n]+//; $_ } _no_end_of_newline_lines;
    is( join( '', $file->lines( { chomp => 1, count => 3 } ) ),
        join( '', @exp[ 0 .. 2 ] ), "lines" );
    is( join( '', $file->lines( { chomp => 1, count => -3 } ) ),
        join( '', @exp[ 0 .. 2 ] ), "lines" );
};

subtest "spew -> lines (count, UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    my @exp = _utf8_lines;
    is( join( '', $file->lines_utf8( { count => 3 } ) ),  join( '', @exp ), "lines" );
    is( join( '', $file->lines_utf8( { count => -3 } ) ), join( '', @exp ), "lines" );
};

subtest "spew -> lines (count, chomp, UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    my @exp = map { s/[\r\n]+//; $_ } _utf8_lines;
    is( join( '', $file->lines_utf8( { chomp => 1, count => 2 } ) ),
        join( '', @exp[ 0 .. 1 ] ), "lines" );
    is( join( '', $file->lines_utf8( { chomp => 1, count => -2 } ) ),
        join( '', @exp[ 1 .. 2 ] ), "lines" );
};

subtest "spew -> lines (chomp, UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_lines), "spew" );
    my @exp = map { s/[\r\n]+//; $_ } _utf8_lines;
    is( join( '', $file->lines_utf8( { chomp => 1 } ) ), join( '', @exp ), "lines" );
};

subtest "spew -> lines (count, UTF-8, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_no_end_of_newline_lines), "spew" );
    my @exp = _utf8_no_end_of_newline_lines;
    is( join( '', $file->lines_utf8( { count => 4 } ) ),  join( '', @exp ), "lines" );
    is( join( '', $file->lines_utf8( { count => -4 } ) ), join( '', @exp ), "lines" );
};

subtest "spew -> lines (count, chomp, UTF-8, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_utf8(_utf8_no_end_of_newline_lines), "spew" );
    my @exp = map { s/[\r\n]+//; $_ } _utf8_no_end_of_newline_lines;
    is( join( '', $file->lines_utf8( { chomp => 1, count => 2 } ) ),
        join( '', @exp[ 0 .. 1 ] ), "lines" );
    is( join( '', $file->lines_utf8( { chomp => 1, count => -2 } ) ),
        join( '', @exp[ 2 .. 3 ] ), "lines" );
};

subtest "spew -> lines (count, raw)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_raw(_lines), "spew" );
    my @exp = _lines;
    is( join( '', $file->lines_raw( { count => 2 } ) ),  join( '', @exp ), "lines" );
    is( join( '', $file->lines_raw( { count => -2 } ) ), join( '', @exp ), "lines" );
};

subtest "spew -> lines (count, raw, no end of newline)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->spew_raw(_no_end_of_newline_lines), "spew" );
    my @exp = _no_end_of_newline_lines;
    is( join( '', $file->lines_raw( { count => 3 } ) ),  join( '', @exp ), "lines" );
    is( join( '', $file->lines_raw( { count => -3 } ) ), join( '', @exp ), "lines" );
};

subtest "append -> slurp" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append(_lines), "append" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "append -> slurp (empty)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append, "append" );
    is( $file->slurp, "", "slurp" );
};

subtest "append -> slurp (arrayref)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append( [_lines] ), "append" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "append -> slurp (piecemeal)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append($_), "piecemeal append" ) for _lines;
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "append -> slurp (binmode)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append( { binmode => ":utf8" }, _utf8_lines ), "append" );
    is( $file->slurp( { binmode => ":utf8" } ), join( '', _utf8_lines ), "slurp" );
};

subtest "append -> slurp (truncate)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append(_lines), "append" );
    is( $file->slurp, join( '', _lines ), "slurp" );
    ok( $file->append( { truncate => 1 }, _lines ), "append with truncate" );
    is( $file->slurp, join( '', _lines ), "slurp" );
};

subtest "append -> slurp (open hint)" => sub {
    plan skip_all => "Needs 5.10" unless $] >= 5.010;
    use open IO => ':utf8';
    my $file = Path::Tiny->tempfile;
    ok( $file->append(_utf8_lines), "append" );
    is( $file->slurp, join( '', _utf8_lines ), "slurp" );
};

subtest "append -> slurp (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append_utf8(_utf8_lines), "append" );
    is( $file->slurp_utf8, join( '', _utf8_lines ), "slurp" );
};

subtest "append -> slurp (truncate, UTF8)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append_utf8(_utf8_lines), "append" );
    is( $file->slurp_utf8, join( '', _utf8_lines ), "slurp" );
    ok( $file->append_utf8( { truncate => 1 }, _utf8_lines ), "append with truncate" );
    is( $file->slurp_utf8, join( '', _utf8_lines ), "slurp" );
};

subtest "append -> slurp (raw)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append_raw(_lines), "append" );
    is( $file->slurp_raw, join( '', _lines ), "slurp" );
};

subtest "append -> slurp (truncate, raw)" => sub {
    my $file = Path::Tiny->tempfile;
    ok( $file->append_raw(_lines), "append" );
    is( $file->slurp_raw, join( '', _lines ), "slurp" );
    ok( $file->append_raw( { truncate => 1 }, _lines ), "append with truncate" );
    is( $file->slurp_raw, join( '', _lines ), "slurp" );
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

subtest "openw -> openr (open hint)" => sub {
    plan skip_all => "Needs 5.10" unless $] >= 5.010;
    use open IO => ':utf8';
    my $file = Path::Tiny->tempfile;
    {
        my $fh = $file->openw;
        ok( ( print {$fh} _utf8_lines ), "openw & print" );
    }
    {
        my $fh = $file->openr;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _utf8_lines ), "openr & read" );
        ok( utf8::is_utf8($got), "is UTF8" );
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
        ok( utf8::is_utf8($got), "is UTF8" );
    }
};

subtest "openw -> openr (raw)" => sub {
    my $file = Path::Tiny->tempfile;
    {
        my $fh = $file->openw_raw;
        ok( ( print {$fh} _lines ), "openw & print" );
    }
    {
        my $fh = $file->openr_raw;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _lines ), "openr & read" );
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

subtest "opena -> openr (open hint)" => sub {
    plan skip_all => "Needs 5.10" unless $] >= 5.010;
    use open IO => ':utf8';
    my $file  = Path::Tiny->tempfile;
    my @lines = _utf8_lines;
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
        is( $got, join( '', _utf8_lines ), "openr & read" );
        ok( utf8::is_utf8($got), "is UTF8" );
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
        ok( utf8::is_utf8($got), "is UTF8" );
    }
};

subtest "opena -> openr (raw)" => sub {
    my $file  = Path::Tiny->tempfile;
    my @lines = _lines;
    {
        my $fh = $file->openw_raw;
        ok( ( print {$fh} shift @lines ), "openw & print one line" );
    }
    {
        my $fh = $file->opena_raw;
        ok( ( print {$fh} @lines ), "opena & print rest of lines" );
    }
    {
        my $fh = $file->openr_raw;
        my $got = do { local $/, <$fh> };
        is( $got, join( '', _lines ), "openr & read" );
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

subtest "openrw (open hint)" => sub {
    plan skip_all => "Needs 5.10" unless $] >= 5.010;
    use open IO => ':utf8';
    my $file = Path::Tiny->tempfile;
    my $fh   = $file->openrw;
    ok( ( print {$fh} _utf8_lines ), "openrw & print" );
    ok( seek( $fh, 0, 0 ), "seek back to start" );
    my $got = do { local $/, <$fh> };
    is( $got, join( '', _utf8_lines ), "openr & read" );
    ok( utf8::is_utf8($got), "is UTF8" );
};

subtest "openrw (UTF-8)" => sub {
    my $file = Path::Tiny->tempfile;
    my $fh   = $file->openrw_utf8;
    ok( ( print {$fh} _utf8_lines ), "openrw & print" );
    ok( seek( $fh, 0, 0 ), "seek back to start" );
    my $got = do { local $/, <$fh> };
    is( $got, join( '', _utf8_lines ), "openr & read" );
    ok( utf8::is_utf8($got), "is UTF8" );
};

subtest "openrw (raw)" => sub {
    my $file = Path::Tiny->tempfile;
    my $fh   = $file->openrw_raw;
    ok( ( print {$fh} _lines ), "openrw & print" );
    ok( seek( $fh, 0, 0 ), "seek back to start" );
    my $got = do { local $/, <$fh> };
    is( $got, join( '', _lines ), "openr & read" );
};

subtest "edit_utf8" => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew_utf8(_utf8_lines);
    $file->edit_utf8(sub { s/^Line/Row/gm; });
    my $line3 = "\302\261\n";
    utf8::decode($line3);
    is(
        $file->slurp_utf8,
        ("Row1\r\nRow2\n$line3"),
        "edit_utf8",
    );
};

subtest "edit_raw" => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew_raw("Foo Bar\nClam Bar\n");
    $file->edit_raw(sub { s/Bar/Mangle/; });
    is(
        $file->slurp_raw,
        "Foo Mangle\nClam Bar\n",
        "edit_raw",
    );
};

subtest "edit_utf8 param" => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew_utf8(_utf8_lines);
    $file->edit_utf8(sub {
        my $text = shift;
        $text =~ s/\ALine/It's my line/;
        $_ = $text;

        return;
    });
    my $line3 = "\302\261\n";
    utf8::decode($line3);
    is(
        $file->slurp_utf8,
        ("It's my line1\r\nLine2\n$line3"),
        "edit_utf8 callback param",
    );
};

subtest "edit_lines_utf8" => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew_utf8("Foo\nBar\nBaz\nQuux\n");
    $file->edit_lines_utf8(sub { s/\A/prefix = /gm; });
    is(
        $file->slurp_utf8,
        ("prefix = Foo\nprefix = Bar\nprefix = Baz\nprefix = Quux\n"),
        "edit_lines_utf8",
    );
};

done_testing;
# COPYRIGHT
