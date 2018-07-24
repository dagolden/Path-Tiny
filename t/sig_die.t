use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Temp qw(tmpnam);

use Path::Tiny;

use lib 't/fakelib';

my $file = path( scalar tmpnam() );
ok $file, 'Got a filename via tmpnam()';

{
    my $fh = $file->openw;
    ok $fh, "Opened $file for writing";

    ok print( $fh "Foo\n" ), "Printed to $file";
}

my $called_handler;

{
    local $SIG{__DIE__} = sub { ++$called_handler };
    $file->slurp_utf8;
}

ok !$called_handler, 'outer $SIG{__DIE__} handler should not be called';

unlink $file;

done_testing;
