use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;
use Digest;
use Digest::SHA3; # for dependency detection

my $dir  = Path::Tiny->tempdir;
my $file = $dir->child('foo.bin');

my $chunk = pack( "Z*", "Hello Path::Tiny\nThis is packed binary string\n" );
ok( $file->spew_raw($chunk), "created test file with packed binary string" );

is(
    $file->digest,
    'a98e605049836e8adb36d351abb95a09e9e5e200703576ecdaec0e697d17d626',
    'digest SHA-256 (hardcoded)',
);

my $sha = Digest->new('SHA-256');
$sha->add($chunk);
my $sha_hex = $sha->hexdigest;
is( $file->digest, $sha_hex, 'digest SHA-256' );
is( $file->digest( { chunk_size => 10 } ), $sha_hex, 'digest SHA-256 (chunked)' );

is(
    $file->digest('SHA3-256'),
    '2447daf270288ec4ff7b73f6bb86343aa7adbcf5ad0a3eea80aeb2d8df19bbda',
    'digest SHA3-256 (hardcoded)',
);

my $sha3 = Digest->new('SHA3-256');
$sha3->add($chunk);
my $sha3_hex = $sha3->hexdigest;
is( $file->digest('SHA3-256'), $sha3_hex, 'digest SHA3-256', );
is( $file->digest( { chunk_size => 10 }, 'SHA3-256' ), $sha3_hex, 'digest SHA3-256 (chunked)' );

done_testing;
# COPYRIGHT
