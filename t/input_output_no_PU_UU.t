use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

# Tiny equivalent of Devel::Hide
BEGIN {
    $INC{'Unicode/UTF8.pm'}       = undef;
    $INC{'PerlIO/utf8_strict.pm'} = undef;
}

note "Hiding Unicode::UTF8 and PerlIO::utf8_strict";

do "t/input_output.t";

# COPYRIGHT
