use 5.008001;
use strict;
use warnings;

package TestUtils;

use Carp;
use Cwd qw/getcwd/;
use Config;
use File::Temp 0.19 ();

use Exporter;
our @ISA    = qw/Exporter/;
our @EXPORT = qw(
  exception
  pushd
  tempd
  has_symlinks
);

# If we have Test::FailWarnings, use it
BEGIN {
    eval { require Test::FailWarnings; 1 } and do { Test::FailWarnings->import };
}

sub has_symlinks {
    return $Config{d_symlink}
      unless $^O eq 'msys' || $^O eq 'MSWin32';

    if ($^O eq 'msys') {
        # msys needs both `d_symlink` and a special environment variable
        return unless $Config{d_symlink};
        return $ENV{MSYS} =~ /winsymlinks:nativestrict/;
    } elsif ($^O eq 'MSWin32') {
        # Perl 5.33.5 adds symlink support for MSWin32 but needs elevated
        # privileges so verify if we can use it for testing.
        my $wd=tempd();
        open my $fh, ">", "foo";
        return eval { symlink "foo", "bar" };
    }
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
    return pushd( File::Temp->newdir );
}

sub pushd {
    my $temp  = shift;
    my $guard = TestUtils::_Guard->new(
        {
            temp   => $temp,
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
