use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings -allow_deps => 1;

use Path::Tiny;
use Cwd 'abs_path';

my $td = Path::Tiny->tempdir->realpath;
$td->child(qw/tmp tmp2/)->mkpath;

my $foo = $td->child(qw/tmp foo/)->touch;
my $bar = $td->child(qw/tmp tmp2 bar/);

symlink $foo, $bar;

ok -f $foo, "it's a file";
ok -l $bar, "it's a link";

is readlink $bar, $foo, "the link seems right";
is abs_path($bar), $foo, "abs_path gets's it right";

note "drumroll";
is $bar->realpath, $foo, "realpath get's it right";

done_testing;

# COPYRIGHT
# vim: set ts=4 sts=4 sw=4 et tw=75:
