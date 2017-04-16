use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;

subtest q[filehandle encodings and $@] => sub {
    local $@ = 'foo';
    Path::Tiny->tempfile->filehandle( ">>", ":unix:encoding(UTF-8)" );
    is $@, 'foo', 'a filehandle with encodings does not clear $@';
};

done_testing;
