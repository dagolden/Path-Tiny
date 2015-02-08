use strict;
use warnings;

use Test::More tests => 3;

use lib 't/lib';

use Path::Tiny qw/ tempfile path_plugins /;

is_deeply [ path_plugins( '+Encrypt::ROT13' ) ]
            => [ 'Path::Tiny::Encrypt::ROT13' ], 'plugin loaded';

# create the file
my $message = "Hello world!";
my $file  = tempfile();
$file->spew_rot13($message);

is $file->slurp => 'Uryyb jbeyq!', 'file is encrypted';

is $file->slurp_rot13 => $message, 'we can decrypt it';
