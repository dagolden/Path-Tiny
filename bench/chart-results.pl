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
        Param("output|o")->default("chart.png"),
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

my @file_order =
  sort { min( @{ $tests->{$b} } ) <=> min( @{ $tests->{$a} } ) } keys %$tests;

my $cc = Chart::Clicker->new( width => 800, height => 300, format => 'png' );

my @series;

my $CCDS = 'Chart::Clicker::Data::Series';

for my $m ( keys %$series_data ) {
    my @keys = ( 1 .. @file_order );
    my @values = map { $series_data->{$m}{$_} } @file_order;
    push @series, $CCDS->new( keys => \@keys, values => \@values );
}

my $ds = Chart::Clicker::Data::DataSet->new( series => \@series, );

$cc->title->text('File utilities');
$cc->title->padding->bottom(5);
$cc->add_to_datasets($ds);

my $defctx = $cc->get_context('default');

$defctx->range_axis->label("#/s");
##$defctx->range_axis->format(
##    sub {
##        my $m = int( $_[0] / 60 );
##        my $s = $_[0] - $m * 60;
##        return sprintf '%u:%05.2f', $m, $s;
##    }
##);

$defctx->domain_axis->label('Benchmarks');
##$defctx->domain_axis->tick_values( [ 1 ..  ] );
##$defctx->domain_axis->format( sub { "1e$_[0]" } );

$defctx->renderer->brush->width(2);

$cc->write_output($opts->get_output);

