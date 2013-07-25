use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use Path::Tiny;
use Digest;

my $file = path('foo.bin');
ok $file;

my $chunk = pack("Z*", "Hello Path::Tiny\nThis is packed binary string\n");
ok( $file->spew_raw($chunk) );

# Digest::SHA was first released with perl v5.9.3.
# And Digest::SHA2 is not a core module.
SKIP: {
    eval { require Digest::SHA; 1 };
    if ($@) {
        eval { require Digest::SHA2; 1 };
        skip "cannot find neither Digest::SHA nor Digest::SHA2", 1 if $@;
    }

    is(
        $file->digest,
        'a98e605049836e8adb36d351abb95a09e9e5e200703576ecdaec0e697d17d626',
        'digest SHA-256 (hardcoded)',
    );

    my $sha = Digest->new('SHA-256');
    $sha->add($chunk);
    is(
        $file->digest,
        $sha->hexdigest,
        'digest SHA-256',
    );
}

is(
    $file->digest('MD5'),
    'ce05aca61c0e58d7396073b668bcafd0',
    'digest MD5 (hardcoded)',
);

my $md5 = Digest->new('MD5');
$md5->add($chunk);
is(
    $file->digest('MD5'),
    $md5->hexdigest,
    'digest MD5',
);

done_testing;
# COPYRIGHT
