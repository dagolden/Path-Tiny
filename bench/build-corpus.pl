#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use autodie;
use Path::Tiny;

my $corpus = path( path($0)->dirname, 'corpus' );
$corpus->remove;
$corpus->mkpath;

my %data = (
    uni   => path( path($0)->dirname, 'source/unicode' )->slurp_raw,
    ascii => path( path($0)->dirname, 'source/ascii' )->slurp_raw,
);

my %sizes = (
    tiny   => 1 * 1024,
    small  => 10 * 1024,
    medium => 100 * 1024,
    large  => 1000 * 1024,
    huge   => 10000 * 1024,
);

while ( my ( $name, $size ) = each %sizes ) {
    while ( my ( $type, $data ) = each %data ) {
        $data = $data x ( int( $size / length $data ) + 2 )
          if $size > length $data;
        $corpus->child("$type-$name")->spew_raw( substr( $data, 0, $size ) );
    }
}
