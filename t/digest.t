use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;
use Digest;
use Digest::MD5; # for dependency detection

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
    $file->digest('MD5'),
    'ce05aca61c0e58d7396073b668bcafd0',
    'digest MD5 (hardcoded)',
);

my $md5 = Digest->new('MD5');
$md5->add($chunk);
my $md5_hex = $md5->hexdigest;
is( $file->digest('MD5'), $md5_hex, 'digest MD5', );
is( $file->digest( { chunk_size => 10 }, 'MD5' ), $md5_hex, 'digest MD5 (chunked)' );

done_testing;
# COPYRIGHT
