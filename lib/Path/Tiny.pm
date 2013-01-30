use v5.10;
use strict;
use warnings;

package Path::Tiny;
# ABSTRACT: File path utility
# VERSION

# Dependencies
use autodie 2.00;
use Cwd              ();
use Exporter         (qw/import/);
use Fcntl            (qw/:flock SEEK_END/);
use File::Copy       ();
use File::Path       ();
use File::Spec       ();
use File::Spec::Unix ();
use File::Temp 0.18 ();

our @EXPORT = qw/path/;

use constant {
    PATH => 0,
    VOL  => 1,
    DIR  => 2,
    FILE => 3,
    TEMP => 4,
};

use overload (
    q{""}    => sub    { $_[0]->[PATH] },
    bool     => sub () { 1 },
    fallback => 1,
);

# constructor function

# stringify objects; normalize to unix separators
sub path {
    $_[0] = "." unless defined $_[0];
    my $path = join( "/", @_ );
    $path = "." unless length $path;
    $path = File::Spec->canonpath($path); # ugh, but probably worth it
    $path =~ tr[\\][/]; # unix convention
    $path =~ s{/$}{} if $path ne "/"; # hack to make splitpath give us a basename
    bless [$path], __PACKAGE__;
}

# constructor methods

sub new { path( $_[1] ) }

sub rootdir { path( File::Spec->rootdir ) }

sub tempfile { unshift @_, 'new'; goto &_temp }

sub tempdir { unshift @_, 'newdir'; goto &_temp }

sub _temp {
    my $method = shift;
    my $temp   = File::Temp->$method(@_);
    my $self   = path($temp);
    $self->[TEMP] = $temp; # keep object alive while we are
    return $self;
}

# private methods

sub _splitpath {
    my ($self) = @_;
    @{$self}[ VOL, DIR, FILE ] = File::Spec->splitpath( $self->[PATH] );
}

# public methods

sub absolute {
    my ( $self, $base ) = @_;
    return $self if $self->is_absolute;
    return path( join "/", $base // Cwd::getcwd, $_[0]->[PATH] );
}

sub append {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    my $fh = $self->opena( $args->{binmode} );
    flock( $fh, LOCK_EX );
    seek( $fh, 0, SEEK_END );
    print {$fh} $_ for @data;
    flock( $fh, LOCK_UN );
    close $fh;
}

sub basename {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[FILE];
    return $self->[FILE];
}

sub child {
    my ( $self, @parts ) = @_;
    return path( join "/", $self->[PATH], @parts );
}

# XXX take a match parameter?  qr or coderef?
sub children {
    my ($self) = @_;
    opendir my $dh, $self->[PATH];
    return map { $self->child($_) } grep { $_ ne '.' && $_ ne '..' } readdir $dh;
}

# XXX do recursively for directories?
sub copy { File::Copy::copy( $_[0]->[PATH], $_[1] ) or die "Copy failed: $!" }

# N.B. This gives trailing slashes.  If that's not desired, for dirs, just use
# "stringify"; for files, use "parent".
sub dirname {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[DIR];
    return length $self->[DIR] ? $self->[DIR] : ".";
}

sub exists { -e $_[0]->[PATH] }

sub filehandle {
    my ( $self, $mode, $binmode ) = @_;
    return $self->[TEMP] if defined $self->[TEMP];
    open my $fh, $mode, $self->[PATH];
    binmode( $fh, $binmode ) if $binmode;
    return $fh;
}

sub is_absolute { substr( $_[0]->dirname, 0, 1 ) eq '/' }

sub is_dir { -d $_[0]->[PATH] }

sub is_file { -f $_[0]->[PATH] }

sub is_relative { substr( $_[0]->dirname, 0, 1 ) ne '/' }

sub iterator {
    my ($self) = @_;
    opendir( my $dh, $self->[PATH] );
    return sub {
        return unless $dh;
        my $next = scalar readdir $dh;
        undef $dh if !defined $next;
        return $next;
    };
}

sub lines {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $fh = $self->openr( $args->{binmode} );
    if ( $args->{count} ) {
        return map { scalar <$fh> } 1 .. $args->{count};
    }
    else {
        return <$fh>;
    }
}

sub lstat { File::stat::stat( $_[0]->[PATH] ) }

sub mkpath {
    my ( $self, $opts ) = @_;
    return File::Path::make_path( $self->[PATH], ref($opts) eq 'HASH' ? $opts : () );
}

sub move { rename $_[0]->[PATH], $_[1] }

sub opena { $_[0]->filehandle( ">>", $_[1] ) }

sub openr { $_[0]->filehandle( "<", $_[1] ) }

sub openrw { $_[0]->filehandle( "+<", $_[1] ) }

sub openw { $_[0]->filehandle( ">", $_[1] ) }

sub parent {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[FILE];
    if ( length $self->[FILE] ) {
        if ( $self->[FILE] eq '.' || $self->[FILE] =~ /\.\./ ) {
            return path( $self->[PATH] . "/.." );
        }
        else {
            return path( $self->[VOL] . $self->[DIR] );
        }
    }
    elsif ( length $self->[DIR] ) {
        if ( $self->[DIR] =~ /\.\./ ) {
            return path( $self->[VOL] . $self->[DIR] . "/.." );
        }
        else {
            return path("/") if $self->[DIR] eq "/";
            ( my $dir = $self->[DIR] ) =~ s{/[^\/]+/$}{/};
            return path( $self->[VOL] . $dir );
        }
    }
    else {
        return path( $self->[VOL] );
    }
}

# Easy to get wrong, so wash it through File::Spec (sigh)
sub relative {
    my ( $self, $base ) = @_;
    return path( File::Spec->abs2rel( $self->[PATH], $base ) );
}

sub remove {
    my ( $self, $opts ) = @_;
    if ( -d $self->[PATH] ) {
        return File::Path::remove_tree( $self->[PATH], ref($opts) eq 'HASH' ? $opts : () );
    }
    else {
        return ( -e $self->[PATH] ) ? unlink $self->[PATH] : 1;
    }
}

sub slurp {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $fh = $self->openr( $args->{binmode} );
    local $/;
    return scalar <$fh>;
}

sub slurp_utf8 { unshift @_, { binmode => ":encoding(UTF-8)" }; goto &slurp }

# N.B. atomic
sub spew {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    my $temp = path( $self->[PATH] . $$ );
    my $fh   = $temp->openw( $args->{binmode} );
    print {$fh} $_ for @data;
    close $fh;
    $temp->rename( $self->[PATH] );
}

sub spew_utf8 { unshift @_, { binmode => ":encoding(UTF-8)" }; goto &spew }

# XXX break out individual stat() components as subs?
sub stat { File::stat::stat( $_[0]->[PATH] ) }

sub stringify { $_[0]->[PATH] }

sub touch {
    my ($self) = @_;
    if ( -e $self->[PATH] ) {
        my $now = time();
        utime $now, $now, $self->[PATH];
    }
    else {
        close $self->openw;
    }
}

sub volume {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[VOL];
    return $self->[VOL];
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  use Path::Tiny;

  my $file = path("/foo/bar");

  ...

=head1 DESCRIPTION

This module attempts to provide a small, fast utility for working with
file paths.  It is friendlier to use than raw L<File::Spec> and provides
easy access to functions from several other core file handling modules.

It doesn't attempt to be as full-featured as L<IO::All> or L<Path::Class>,
nor does it try to work for anything except Unix-like and Win32 platforms.

It tries to be fast, with as minimal overhead over File::Spec as possible.

All paths are converted to Unix-style forward slashes.

=head1 USAGE

To be written.

=head1 SEE ALSO

=for :list
* L<File::Fu>
* L<IO::All>
* L<Path::Class>

Probably others.  Let me know if you want me to add some.

=cut

# vim: ts=4 sts=4 sw=4 et:
