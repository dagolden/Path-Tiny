use strict;
use warnings;
use Test::More 0.88;
use Path::Tiny;

use lib 't/lib';
use TestUtils qw/exception tempd/;
use Path::Tiny;

my $wd = tempd;

my @tree = qw(
  base/Bethlehem/XDG/gift_list.txt
  base/Vancouver/ETHER/.naughty
  base/Vancouver/ETHER/gift_list.txt
  base/New_York/XDG/gift_list.txt
);
path($_)->touchpath for @tree;

my @files;
my $iter = path('base')->iterator({ recurse => 1 });
my $exception = exception {
  while (my $path = $iter->())
  {
    $path->remove_tree if $path->child('.naughty')->is_file;
    push @files, $path if $path->is_file;
  }
};

is($exception, '', 'can remove directories while traversing');
is_deeply(
  \@files,
  [ 'base/Bethlehem/XDG/gift_list.txt', 'base/New_York/XDG/gift_list.txt' ],
  'remaining files',
);

done_testing;
