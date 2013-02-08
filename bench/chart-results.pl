#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use autodie;

use Chart::Clicker;
use Chart::Clicker::Context;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Data::Marker;
use Chart::Clicker::Data::Series;
use Geometry::Primitive::Rectangle;
use Graphics::Color::RGB;
use Geometry::Primitive::Circle;

use List::AllUtils qw(max sum min);
use Path::Tiny;
use JSON;

use Getopt::Lucid ':all';

{
    my $log10 = log(10);
    sub log10 { return log( $_[0] ) / $log10 }
}

sub iter_per_sec {
    my ( $real, $user, $system, $children_user, $children_system, $iters ) = @{ $_[0] };
    return $iters / sum( $user, $system, $children_user, $children_system, 0.00000001 );
}

my $opts = Getopt::Lucid->getopt(
    [
        Param("input|i")->default("results.json"),
        Param("output|o")->default("output.png"),
        Param("sort")->default("tiny")->valid(qw/^(?:tiny|min|max|sum)$/),
    ]
)->validate;

my $bench_data = from_json( path( $opts->get_input )->slurp_raw );

# bench data is file->module->data
# we need to pivot that to module->file->data

my $tests;
my $series_data;
my @range_vals;

for my $file ( keys %$bench_data ) {
    for my $mod ( keys %{ $bench_data->{$file} } ) {
        my $iters = iter_per_sec( $bench_data->{$file}{$mod} );
        $series_data->{$mod}{$file} = $iters;
        push @{ $tests->{$file} }, $iters;
        push @range_vals, log10($iters);
    }
}

my $N_tests = keys %$tests;
my @file_order;

my $sort = $opts->get_sort;
if ( $sort eq 'sum' ) {
    @file_order =
      sort { sum( @{ $tests->{$b} } ) <=> sum( @{ $tests->{$a} } ) } keys %$tests;
}
elsif ( $sort eq 'min' ) {
    @file_order =
      sort { min( @{ $tests->{$b} } ) <=> min( @{ $tests->{$a} } ) } keys %$tests;
}
elsif ( $sort eq 'max' ) {
    @file_order =
      sort { max( @{ $tests->{$b} } ) <=> max( @{ $tests->{$a} } ) } keys %$tests;
}
elsif ( $sort eq 'tiny' ) { # sort by Path::Tiny results
    @file_order =
      sort { $series_data->{'Path::Tiny'}{$b} <=> $series_data->{'Path::Tiny'}{$a} }
      keys %$bench_data;
}
else {
    die "Unknown sort '$sort'\n";
}

my $cc = Chart::Clicker->new( width => 800, height => 600, format => 'png' );

my @series;
my $CCDS = 'Chart::Clicker::Data::Series';

for my $m ( sort keys %$series_data ) {
    my @keys = ( 1 .. @file_order );
    my @values = map { log10( $series_data->{$m}{$_} ) } @file_order;
    push @series, $CCDS->new( keys => \@keys, values => \@values, name => $m );
}

my $ds = Chart::Clicker::Data::DataSet->new( series => \@series, );

$cc->title->text('File utility benchmarking');
$cc->title->padding->bottom(5);
$cc->add_to_datasets($ds);

my $defctx = $cc->get_context('default');

my $min_range = int( min(@range_vals) );
my $max_range = int( max(@range_vals) + 1 );

$defctx->range_axis->label("#/sec");
$defctx->range_axis->tick_values( [ $min_range .. $max_range ] );
$defctx->range_axis->range->min($min_range);
$defctx->range_axis->range->max($max_range);
$defctx->range_axis->format( sub { "1" . ( "0" x $_[0] ) } );

$defctx->domain_axis->label('Benchmark file');
$defctx->domain_axis->tick_values( [ 1 .. @file_order ] );
$defctx->domain_axis->tick_label_angle(1.57);
$defctx->domain_axis->format( sub { $file_order[ $_[0] - 1 ] } );

$defctx->renderer->brush->width(2);

say "Writing " . $opts->get_output;
$cc->write_output( $opts->get_output );

