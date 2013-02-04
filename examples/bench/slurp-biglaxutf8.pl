#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw( cmpthese :hireswallclock );
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $file = "$ENV{HOME}/tmp/BIGAUTHORS";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { my $s = path($file)->slurp({binmode => ":utf8"}) },
        'Path::Class' => sub { my $s = file($file)->slurp(iomode => "<:utf8") },
        'IO::All'     => sub { my $s = io($file)->utf8->slurp },
        'File::Fu'    => sub { my $s = File::Fu->file($file)->read({binmode => ":utf8"}) },
    }
);

