#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use Benchmark::Forking qw( timethese );
use Getopt::Lucid qw/:all/;
use JSON -convert_blessed_universally;
use Path::Tiny;
use aliased 'Path::Iterator::Rule' => 'PIR';

my %default_count = (
    tests        => -2,
    construct    => -1,
    manip        => -1,
    slurp        => 100,
    'slurp-utf8' => 100,
);

my @spec = (
    Param('count|c'),
    Param('output|o')->default("results.json"),
    Param("tests|t")->default("tests"),
);

my $opts = Getopt::Lucid->getopt( \@spec )->validate;

my $count = $opts->get_count // $default_count{ $opts->get_tests } // -1;

my %results;

my $tests = path( $opts->get_tests );

for my $t ( map { path($_) } PIR->new->file->all($tests) ) {
    say "Running $t...";
    my $pl = Path::Tiny->tempfile;
    $pl->spew_raw( _test_guts( $count, $t->slurp_raw ) );
    my $string = join( "", grep { $_ !~ /warning: too few/ } qx/$^X $pl/ );
    eval { $results{ $t->basename } = JSON->new->decode($string) }
      or warn "ERROR DECODING:\n$string";
}

say "Writing " . $opts->get_output;
path( $opts->get_output )->spew_raw( JSON->new->pretty->encode( \%results ) );

exit;

sub _test_guts {
    my ( $count, $snippet ) = @_;
    my $guts = _test_shell();
    $guts =~ s/COUNT/$count/;
    $guts =~ s/TIMETHESE/$snippet/;
    return $guts;
}

sub _test_shell {
    return <<'HERE';
#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

use Benchmark::Forking qw( timethese );
use JSON -convert_blessed_universally;

use File::Fu;
use IO::All;
use Path::Class;
use Path::Tiny;

my $count = COUNT;

TIMETHESE

print JSON->new->allow_blessed->convert_blessed->encode($result);
HERE
}
