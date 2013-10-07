use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Spec;
use Cwd;

use lib 't/lib';
use TestUtils qw/exception/;

use Fcntl ':flock';
use Path::Tiny;

my $IS_BSD = $^O =~ /bsd$/;

if ($IS_BSD) {
    # is temp partition lockable?
    my $file = Path::Tiny->tempfile;
    open my $fh, ">>", $file;
    flock $fh, "LOCK_EX"
      or plan skip_all => "Can't lock tempfiles on this OS/filesystem";
}

subtest 'write locks blocks read lock' => sub {
    my $file = Path::Tiny->tempfile;
    ok $file, "Got a tempfile";
    my $fh = $file->openw( { locked => 1 } );
    ok $fh, "Opened file for writing with lock";
    $fh->autoflush(1);
    print {$fh} "hello";
    open my $fh2, "<", "$file";
    ok( $fh2, "opened again for reading" );
    ok( !flock( $fh2, LOCK_SH | LOCK_NB ), "read lock not available" );
};

done_testing;
