#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;
use Benchmark::Forking qw( timethese );
use Getopt::Lucid qw/:all/;
use JSON -convert_blessed_universally;
use Path::Tiny;

my @spec = (
    Param('count|c')->default(-1),
    Param('output|o')->default("results.json"),
    Param("tests|t")->default("tests"),
);

my $opts = Getopt::Lucid->getopt( \@spec )->validate;

my %results;

my $tests = path($opts->get_tests);

for my $t ( $tests->children ) {
    say "Running $t...";
    my $pl = Path::Tiny->tempfile;
    $pl->spew_raw( _test_guts( $opts->get_count, $t->slurp_raw ) );
    my $string = join( "", grep { $_ !~ /warning: too few/ } qx/$^X $pl/ );
    eval { $results{$t->basename} = JSON->new->decode($string) }
        or warn "ERROR DECODING:\n$string";
}

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
