#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark::Forking qw/cmpthese/;
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { path("$ENV{HOME}/foo.txt") },
        'Path::Class' => sub { file("$ENV{HOME}/foo.txt") },
        'IO::All'     => sub { io("$ENV{HOME}/foo.txt") },
        'File::Fu'    => sub { File::Fu->file("$ENV{HOME}/foo.txt") },
    }
);

