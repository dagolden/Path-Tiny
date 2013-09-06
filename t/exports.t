use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use Test::FailWarnings;
use Test::Fatal;

use Path::Tiny qw/path cwd rootdir tempdir tempfile/;

isa_ok( path("."), 'Path::Tiny', 'path' );
isa_ok( cwd, 'Path::Tiny', 'cwd' );
isa_ok( rootdir, 'Path::Tiny', 'rootdir' );
isa_ok( tempfile( TEMPLATE => 'tempXXXXXXX' ), 'Path::Tiny', 'tempfile' );
isa_ok( tempdir( TEMPLATE => 'tempXXXXXXX' ), 'Path::Tiny', 'tempdir' );

done_testing;
# COPYRIGHT
# vim: ts=4 sts=4 sw=4 et:
