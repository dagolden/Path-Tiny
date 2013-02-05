#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark::Forking qw/cmpthese/;
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $file = "$ENV{HOME}/git/perl/AUTHORS";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { my $s = path($file)->slurp_utf8 },
        'Path::Class' => sub { my $s = file($file)->slurp(iomode => "<:encoding(UTF-8)") },
        'IO::All'     => sub { my $s = io($file)->binmode(":encoding(UTF-8)")->slurp },
        'File::Fu'    => sub { my $s = File::Fu->file($file)->read({binmode => ":encoding(UTF-8)"}) },
    }
);

