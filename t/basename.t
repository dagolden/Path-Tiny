use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;
use Cwd;

my $IS_WIN32 = $^O eq 'MSWin32';

my @cases = (
    [ 'foo.txt', [ '.txt',    '.png' ],    'foo' ],
    [ 'foo.png', [ '.txt',    '.png' ],    'foo' ],
    [ 'foo.txt', [ qr/\.txt/, qr/\.png/ ], 'foo' ],
    [ 'foo.png', [ qr/\.txt/, qr/\.png/ ], 'foo' ],
    [ 'foo.txt', ['.jpeg'], 'foo.txt' ],
    [ 'foo/.txt/bar.txt', [ qr/\.txt/, qr/\.png/ ], 'bar' ],
);

for my $c (@cases) {
    my ( $input, $args, $result ) = @$c;
    my $path = path($input);
    my $base = $path->basename(@$args);
    is( $base, $result, "$path -> $result" );
}

done_testing;
# COPYRIGHT
