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

my $opts = Getopt::Lucid->getopt(
    [
        Param("input|i")->default("results.json"),
        Param("output|o")->default("output.png"),
    ]
)->validate;

my $bench_data = from_json( path( $opts->get_input )->slurp_raw );

# bench data is file->module->data
# we need to pivot that to module->file->data

my $tests;
my $series_data;
for my $file ( keys %$bench_data ) {
    for my $mod ( keys %{ $bench_data->{$file} } ) {
        my $iters = $bench_data->{$file}{$mod}[-1];
        $series_data->{$mod}{$file} = $iters;
        push @{ $tests->{$file} }, $iters;
    }
}

my $N_tests = keys %$tests;
my @file_order =
  sort { sum( @{ $tests->{$b} } )/$N_tests <=> sum( @{ $tests->{$a} } )/$N_tests } keys %$tests;

my $cc = Chart::Clicker->new( width => 800, height => 600, format => 'png' );

my @series;

my $CCDS = 'Chart::Clicker::Data::Series';

for my $m ( keys %$series_data ) {
    my @keys = ( 1 .. @file_order );
    my @values = map { log($series_data->{$m}{$_})/log(10) } @file_order;
    push @series, $CCDS->new( keys => \@keys, values => \@values, name => $m );
}

my $ds = Chart::Clicker::Data::DataSet->new( series => \@series, );

$cc->title->text('File utility benchmarking');
$cc->title->padding->bottom(5);
$cc->add_to_datasets($ds);

my $defctx = $cc->get_context('default');

$defctx->range_axis->label("#/sec");
$defctx->range_axis->tick_values( [0 .. 6] );
$defctx->range_axis->range->min(0);
$defctx->range_axis->range->max(6);
$defctx->range_axis->format( sub { "1" . ("0" x $_[0]) } );

$defctx->domain_axis->label('Benchmark file');
$defctx->domain_axis->tick_values( [ 1 .. @file_order ] );
$defctx->domain_axis->tick_label_angle(1.57);
$defctx->domain_axis->format( sub { $file_order[$_[0]-1] } );

$defctx->renderer->brush->width(2);

$cc->write_output($opts->get_output);

