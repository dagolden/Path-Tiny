use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';

use Path::Tiny;

my $tmpdir     = Path::Tiny->tempdir;
my @testfiles  = qw{foo-bar foo\bar};
my $teststring = "Das ist der Rand von Ostermundigen.\n";
my $orig       = Path::Tiny->cwd;

plan tests => 2 + 9 * @testfiles;

ok chdir $tmpdir;

for my $testfile (@testfiles) {
    SKIP: {
        open my $fh, '>', $testfile
          or skip "Cannot create $testfile on this platform.", 9;

        ok print $fh $teststring;
        ok close $fh;

        my $data;
        ok my $path = path($testfile);
        eval { $data = $path->slurp_raw };
        is $@, '', "opening $testfile";
        is $data, $teststring, "read data from $testfile";

        ok my $iter = Path::Tiny->cwd->iterator;
        my @found;
        while ( my $path = $iter->() ) {
            ok $path->exists, "path $path returned by iterator exists";
            push @found, $path;
        }
        is scalar @found, 1;

        ok unlink $testfile;
    }
}

ok chdir $orig;
