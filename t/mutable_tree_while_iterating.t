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

subtest 'iterator' => sub {
    my @files;
    my $iter = path('base')->iterator( { recurse => 1 } );
    my $exception = exception {
        while ( my $path = $iter->() ) {
            $path->remove_tree if $path->child('.naughty')->is_file;
            push @files, $path if $path->is_file;
        }
    };

    is( $exception, '', 'can remove directories while traversing' );
    is_deeply(
        [ sort @files ],
        [ 'base/Bethlehem/XDG/gift_list.txt', 'base/New_York/XDG/gift_list.txt' ],
        'remaining files',
    );
};

subtest 'visit' => sub {
    my @files;
    my $exception = exception {
        path('base')->visit(
            sub {
                my $path = shift;
                $path->remove_tree if $path->child('.naughty')->is_file;
                push @files, $path if $path->is_file;
            },
            { recurse => 1 },
        );
    };

    is( $exception, '', 'can remove directories while traversing' );
    is_deeply(
        [ sort @files ],
        [ 'base/Bethlehem/XDG/gift_list.txt', 'base/New_York/XDG/gift_list.txt' ],
        'remaining files',
    );
};

done_testing;
