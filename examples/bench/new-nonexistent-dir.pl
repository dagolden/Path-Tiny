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
        'Path::Tiny'  => sub { path("$ENV{HOME}/foo") },
        'Path::Class' => sub { dir("$ENV{HOME}/foo") },
        'IO::All'     => sub { io("$ENV{HOME}/foo") },
        'File::Fu'    => sub { File::Fu->dir("$ENV{HOME}/foo") },
    }
);

