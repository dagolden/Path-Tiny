#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw( cmpthese :hireswallclock );
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { path($ENV{HOME})->children },
        'Path::Class' => sub { dir($ENV{HOME})->children },
        'IO::All'     => sub { io($ENV{HOME})->all },
        'File::Fu'    => sub { File::Fu->dir($ENV{HOME})->list },
    }
);

