use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Spec;
use File::Glob;
use Path::Tiny;
use Cwd;

use lib 't/lib';
use TestUtils qw/exception/;

my $file1 = path(\'foo.txt');
isa_ok( $file1, "Path::Tiny" );

ok "$file1" eq "t/foo.txt", "Caller relative via ref";

my $file2 =Path::Tiny->new(\'foo.txt');
isa_ok( $file2, "Path::Tiny" );

ok "$file2" eq "t/foo.txt", "Caller relative via ref (from constructor)";

done_testing();
