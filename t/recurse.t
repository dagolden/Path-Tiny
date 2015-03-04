use 5.006;
use strict;
use warnings;
use Test::More 0.92;
use File::Temp;
use Config;

use lib 't/lib';
use TestUtils qw/exception tempd/;

use Path::Tiny;

#--------------------------------------------------------------------------#

subtest 'no symlinks' => sub {
    my $wd = tempd;

    my @tree = qw(
      aaaa.txt
      bbbb.txt
      cccc/dddd.txt
      cccc/eeee/ffff.txt
      gggg.txt
    );

    my @breadth = qw(
      aaaa.txt
      bbbb.txt
      cccc
      gggg.txt
      cccc/dddd.txt
      cccc/eeee
      cccc/eeee/ffff.txt
    );

    path($_)->touchpath for @tree;

    subtest 'iterator' => sub {
        my $iter = path(".")->iterator( { recurse => 1 } );

        my @files;
        while ( my $f = $iter->() ) {
            push @files, "$f";
        }

        is_deeply( [ sort @files ], [ sort @breadth ], "Breadth first iteration" )
          or diag explain \@files;
    };
    subtest 'visit' => sub {
        my @files;
        path(".")->visit( sub { push @files, "$_[0]" }, { recurse => 1 }, );

        is_deeply( [ sort @files ], [ sort @breadth ], "Breadth first iteration" )
          or diag explain \@files;
    };
    subtest 'visit state' => sub {
        my $result = path(".")->visit( sub { $_[1]->{$_}++ }, { recurse => 1 }, );

        is_deeply( [ sort keys %$result ], [ sort @breadth ], "Breadth first iteration" )
          or diag explain $result;
    };
    subtest 'visit abort' => sub {
        my $result =
          path(".")->visit( sub { return \0 if ++$_[1]->{count} == 2 }, { recurse => 1 } );

        is( $result->{count}, 2, "visitor aborted on false scalar ref" );
    };
};

subtest 'with symlinks' => sub {
    plan skip_all => "No symlink support"
      unless $Config{d_symlink};

    my $wd = tempd;

    my @tree = qw(
      aaaa.txt
      bbbb.txt
      cccc/dddd.txt
      cccc/eeee/ffff.txt
      gggg.txt
    );

    my @follow = qw(
      aaaa.txt
      bbbb.txt
      cccc
      gggg.txt
      pppp
      qqqq.txt
      cccc/dddd.txt
      cccc/eeee
      cccc/eeee/ffff.txt
      pppp/ffff.txt
    );

    my @nofollow = qw(
      aaaa.txt
      bbbb.txt
      cccc
      gggg.txt
      pppp
      qqqq.txt
      cccc/dddd.txt
      cccc/eeee
      cccc/eeee/ffff.txt
    );

    path($_)->touchpath for @tree;

    symlink path( 'cccc', 'eeee' ), path('pppp');
    symlink path('aaaa.txt'), path('qqqq.txt');

    subtest 'no follow' => sub {
        # no-follow
        subtest 'iterator' => sub {
            my $iter = path(".")->iterator( { recurse => 1 } );
            my @files;
            while ( my $f = $iter->() ) {
                push @files, "$f";
            }
            is_deeply( [ sort @files ], [ sort @nofollow ], "Don't follow symlinks" )
              or diag explain \@files;
        };
        subtest 'visit' => sub {
            my @files;
            path(".")->visit( sub { push @files, "$_[0]" }, { recurse => 1 }, );
            is_deeply( [ sort @files ], [ sort @nofollow ], "Don't follow symlinks" )
              or diag explain \@files;
        };
    };

    subtest 'follow' => sub {
        subtest 'iterator' => sub {
            my $iter = path(".")->iterator( { recurse => 1, follow_symlinks => 1 } );
            my @files;
            while ( my $f = $iter->() ) {
                push @files, "$f";
            }
            is_deeply( [ sort @files ], [ sort @follow ], "Follow symlinks" )
              or diag explain \@files;
          },
          subtest 'visit' => sub {
            my @files;
            path(".")
              ->visit( sub { push @files, "$_[0]" }, { recurse => 1, follow_symlinks => 1 }, );
            is_deeply( [ sort @files ], [ sort @follow ], "Follow symlinks" )
              or diag explain \@files;
          },
          ;
    };
};

done_testing;
# COPYRIGHT
