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

{
    # is temp partition lockable?
    my $file = Path::Tiny->tempfile;
    open my $fh, ">>", $file;
    flock $fh, LOCK_EX
      or plan skip_all => "Can't lock tempfiles on this OS/filesystem";
}

# Guard against external environment
local $ENV{PERL_PATH_TINY_NO_FLOCK} = 0;

subtest 'write locks blocks read lock' => sub {
    my $rc = check_flock();
    is( $rc >> 8, 0, "subprocess failed to get lock" );
};

subtest 'flock ignored if PERL_PATH_TINY_NO_FLOCK=1' => sub {
    local $ENV{PERL_PATH_TINY_NO_FLOCK} = 1;
    my $rc = check_flock();
    is( $rc >> 8, 1, "subprocess managed to get lock" );
};

sub check_flock {
    my $file = Path::Tiny->tempfile;
    ok $file, "Got a tempfile";
    my $fh = $file->openw( { locked => 1 } );
    ok $fh, "Opened file for writing with lock";
    $fh->autoflush(1);
    print {$fh} "hello";
    # check if a different process can get a lock; use RW mode for AIX
    my $locktester = Path::Tiny->tempfile;
    $locktester->spew(<<"HERE");
use strict;
use warnings;
use Fcntl ':flock';
open my \$fh, "+<", "$file";
exit flock( \$fh, LOCK_SH|LOCK_NB );
HERE
    my $rc = system( $^X, $locktester );
    isnt( $rc, -1, "ran process to try to get lock" );
    return $rc;
}

done_testing;
