use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Temp 0.18 ();

use Path::Tiny;

my $tempdir = File::Temp->newdir;

my $path = path($tempdir)->child("foo");

ok( ! -e $path, "target directory not created yet" );
ok( $path->mkpath, "mkpath on directory returned true" );
ok( -d $path, "target directory created" );

my $path2 = path($tempdir)->child("bar");
ok( ! -e $path2, "target directory not created yet" );
ok( $path2->mkpath({mode => 0700}), "mkpath on directory with mode" );
is( $path2->stat->mode & 0777, 0700, "correct mode" );
ok( -d $path2, "target directory created" );

done_testing;
# COPYRIGHT
