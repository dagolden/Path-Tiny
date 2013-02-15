#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use Getopt::Lucid qw/:all/;
use Dumbbench;
use JSON -convert_blessed_universally;
use lib "../lib";
use File::pushd qw/tempd/;
use File::Fu;
use IO::All;
use Path::Class;
use Path::Tiny;
use Statistics::Histogram;

use aliased 'Path::Iterator::Rule' => 'PIR';

my %default_count = (
    'construct' => -1,
    'manip'     => -2,
);

my @spec = (
    Param('count|c'),
    Param('output|o')->default("dumbresults.json"),
    Param("tests|t")->default("tests"),
    Param("corpus|C")->default("corpus"),
    Switch("debug"),
);

my $opts = Getopt::Lucid->getopt( \@spec )->validate;

my $count = $opts->get_count // $default_count{ path( $opts->get_tests )->basename }
  // -3;

my $corpus = path( $opts->get_corpus )->absolute;
die "Corpus $corpus not found"
  unless $corpus->exists;

say "Beginning tests with count = $count:";

my %results;

my $tests = path( $opts->get_tests );

TEST: for my $t ( map { path($_) } PIR->new->file->all($tests) ) {
    say "... $t";
    my $fragment = _test_guts( $t->absolute, $count, $t->slurp_raw );
    my $result;
    my $tmpdir;
    eval $fragment; # XXX naughty string eval!
    my $instances = $result;
    warn $@ if $@;
    my $bench     = Dumbbench->new(
        variability_measure => 'std_dev',
        target_rel_precision => 0.01, # seek ~0.5%
        initial_runs         => 50,   # the higher the more reliable
        max_iteratiions => 10000,
        verbosity => 1,
    );
    $bench->add_instances(@$instances);
    $bench->run;
    for my $i (@$instances) {
        if ( 0 == $i->result->number ) {
            say "Bad result for " . $i->name;
            warn get_histogram( $i->timings );
            path("log-bad.txt")->spew( join("\n", @{$i->timings}) );
            redo TEST;
        }
        $results{ $t->basename }{ $i->name } = $i->result->number;
    }
}

say "Writing " . $opts->get_output;
path( $opts->get_output )->spew_raw( JSON->new->pretty->encode( \%results ) );

exit;

sub timethese {
    my ( $count, $tests, $style ) = @_;
    my @instances;
    while ( my ( $k, $v ) = each %$tests ) {
        push @instances, Dumbbench::Instance::PerlSub->new( name => $k, code => $v ),;
    }
    return \@instances;
}

sub _test_guts {
    my ( $name, $count, $snippet ) = @_;
    my $guts = _test_shell();
    $guts =~ s/COUNT/$count/;
    $guts =~ s/CORPUS/$corpus/;
    $guts =~ s/TEST/$name/;
    $guts =~ s/TIMETHESE/$snippet/;
    say "# $name\n$guts\n" if $opts->get_debug;
    return $guts;
}

sub _test_shell {
    return <<'HERE';
my $count = COUNT;
my $corpus = path("CORPUS");
my $test = path("TEST");

TIMETHESE

HERE
}
