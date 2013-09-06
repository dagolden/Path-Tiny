use 5.008001;
use strict;
use warnings;

package TestUtils;

use Carp;
use Cwd qw/getcwd/;
use File::Temp 0.19 ();

use Exporter;
our @ISA    = qw/Exporter/;
our @EXPORT = qw(
  exception
  tempd
);

# If we have Test::FailWarnings, use it
BEGIN {
    eval { require Test::FailWarnings; 1 } and do { Test::FailWarnings->import };
}

sub exception(&) {
    my $code    = shift;
    my $success = eval { $code->(); 1 };
    my $err     = $@;
    return '' if $success;
    croak "Execution died, but the error was lost" unless $@;
    return $@;
}

sub tempd {
    my $guard = TestUtils::_Guard->new(
        {
            temp   => File::Temp->newdir,
            origin => getcwd(),
            code   => sub { chdir $_[0]{origin} },
        }
    );
    chdir $guard->{temp}
      or croak("Couldn't chdir: $!");
    return $guard;
}

package TestUtils::_Guard;

sub new { bless $_[1], $_[0] }

sub DESTROY { $_[0]{code}->( $_[0] ) }

1;
