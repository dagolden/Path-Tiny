use 5.008001;
use strict;
use warnings;
package TestUtils;

use Carp;

use Exporter;
our @ISA = qw/Exporter/;
our @EXPORT = qw(
    exception
);

# If we have Test::FailWarnings, use it
BEGIN {
    eval { require Test::FailWarnings; 1 } and do { Test::FailWarnings->import };
}

sub exception(&) {
    my $code = shift;
    my $success = eval { $code->(); 1 };
    my $err = $@;
    return '' if $success;
    croak "Execution died, but the error was lost" unless $@;
    return $@;
}

1;
