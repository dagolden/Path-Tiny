#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark::Forking qw/cmpthese/;
use Path::Tiny;
use Path::Class;
use File::Fu;
use IO::All;

print "$0\n";

my $tmpdir = Path::Tiny->tempdir;
my $dir = $tmpdir->child("foo");
$dir->mkpath;
$dir = "$dir";

my $count = -1;
cmpthese(
    $count,
    {
        'Path::Tiny'  => sub { path($dir) },
        'Path::Class' => sub { file($dir) },
        'IO::All'     => sub { io($dir) },
        'File::Fu'    => sub { File::Fu->file($dir) },
    }
);

