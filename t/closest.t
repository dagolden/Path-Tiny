#!/usr/bin/env perl

use 5.008001;
use strict;
use warnings;

use Test::Simple tests => 4;

use Path::Tiny qw/path/;

ok( path('foo/bar/then/there')->closest('then')->stringify eq path( 'foo/bar/then' )->absolute->stringify );
ok( path('foo/bar/then/there')->closest('notther') == 0 );
ok( path('foo/bar/then/there')->closest('bar')->stringify eq path( 'foo/bar' )->absolute->stringify );
ok( path('foo/bar/then/there')->closest('notthere', '/other')->stringify eq path( '/other' )->absolute->stringify );

