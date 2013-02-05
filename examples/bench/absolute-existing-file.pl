#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark::Forking qw/cmpthese/;
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $file = "fooabc123.txt";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { path($file)->absolute },
        'Path::Class' => sub { file($file)->absolute },
        'IO::All'     => sub { io($file)->absolute },
        'File::Fu'    => sub { File::Fu->file($file)->absolute },
    }
);

