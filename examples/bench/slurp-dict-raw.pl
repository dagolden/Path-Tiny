#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw( cmpthese :hireswallclock );
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $file = "/usr/share/dict/words";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { my $s = path($file)->slurp_raw },
        'Path::Class' => sub { my $s = file($file)->slurp(iomode => "<:raw") },
        'IO::All'     => sub { my $s = io($file)->binary->slurp },
        'File::Fu'    => sub { my $s = File::Fu->file($file)->read({binmode => ":raw"}) },
    }
);

