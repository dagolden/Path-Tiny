#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use Getopt::Lucid qw/:all/;
use JSON -convert_blessed_universally;
use lib "../lib";
use Path::Tiny;
use aliased 'Path::Iterator::Rule' => 'PIR';

my %default_count = (
    'construct'         => -1,
    'manip'             => -2,
);

my @spec = (
    Param('count|c'),
    Param('output|o')->default("results.json"),
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

for my $t ( map { path($_) } PIR->new->file->all($tests) ) {
    say "... $t";
    my $pl = Path::Tiny->tempfile;
    $pl->spew_raw( _test_guts( $t->absolute, $count, $t->slurp_raw ) );
    my $string = join( "", grep { $_ !~ /warning: too few/ } qx/$^X $pl/ );
    eval { $results{ $t->basename } = JSON->new->decode($string) }
      or warn "ERROR DECODING:\n$string";
}

say "Writing " . $opts->get_output;
path( $opts->get_output )->spew_raw( JSON->new->pretty->encode( \%results ) );

exit;

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
#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Benchmark qw( :hireswallclock );
use Benchmark::Forking qw( timethese );
use JSON -convert_blessed_universally;
use File::pushd qw/tempd/;

use File::Fu;
use IO::All;
use Path::Class;
use Path::Tiny;

my $count = COUNT;
my $corpus = path("CORPUS");
my $test = path("TEST");
my $result;

TIMETHESE

print JSON->new->allow_blessed->convert_blessed->encode($result);
HERE
}
