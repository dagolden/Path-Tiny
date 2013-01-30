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
use File::Stat       ();
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

#--------------------------------------------------------------------------#
# Constructors
#--------------------------------------------------------------------------#

=construct path

    $path = path("foo/bar");
    $path = path("/tmp/file.txt");
    $path = path(); # like path(".")

Constructs a C<Path::Tiny> object.  It doesn't matter if you give a file or
directory path.  It's still up to you to call directory-like methods only on
directories and file-like methods only on files.  This function is exported
automatically by default.

=cut

sub path {
    $_[0] = "." unless defined $_[0];
    my $path = join( "/", @_ ); # stringifies any objects, too :-)
    $path = "." unless length $path;
    $path = File::Spec->canonpath($path); # ugh, but probably worth it
    $path =~ tr[\\][/]; # unix convention enforced
    $path =~ s{/$}{} if $path ne "/"; # hack to make splitpath give us a basename
    bless [$path], __PACKAGE__;
}

=construct new

    $path = Path::Tiny->new("foo/bar");

This is just like C<path>, but with method call overhead.  (Why would you
do that?)

=cut

sub new { path( $_[1] ) }

=construct rootdir

    $path = Path::Tiny->rootdir; # /

Gives you C<File::Spec->rootdir> as a C<Path::Tiny> object if you're too
picky for C<path("/")>.

=cut

sub rootdir { path( File::Spec->rootdir ) }

=construct tempfile

    $temp = Path::Tiny->tempfile( @options );

This passes the options to C<< File::Temp->new >> and returns a C<Path::Tiny>
object with the file name.  If you want a template, you must use a C<TEMPLATE>
named argument.  The C<TMPDIR> option is enabled by default.

The resulting C<File::Temp> object is cached.  The C<filehandle> method (and
anything that uses it internally) will return the cached object handle rather
than opening a new one, but any binmode options will be applied.

When the C<Path::Tiny> object is destroyed, the C<File::Temp> object will be as
well.

=cut

sub tempfile { shift; unshift @_, 'new'; goto &_temp }

=construct tempdir

    $temp = Path::Tiny->tempdir( @options );

This is just like C<tempfile>, except it calls C<< File::Temp->newdir >> instead.

=cut

sub tempdir { shift; unshift @_, 'newdir'; goto &_temp }

sub _temp {
    my ( $method, @args ) = @_;
    my $temp = File::Temp->$method( TMPDIR => 1, @args );
    my $self = path($temp);
    $self->[TEMP] = $temp; # keep object alive while we are
    return $self;
}

#--------------------------------------------------------------------------#
# Private methods
#--------------------------------------------------------------------------#

sub _splitpath {
    my ($self) = @_;
    @{$self}[ VOL, DIR, FILE ] = File::Spec->splitpath( $self->[PATH] );
}

#--------------------------------------------------------------------------#
# Public methods
#--------------------------------------------------------------------------#

=method absolute

    $abs = path("foo/bar")->absolute;
    $abs = path("foo/bar")->absolute("/tmp");

Returns a new C<Path::Tiny> object with an absolute path.  Unless
an argument is given, the current directory is used as the absolute base path.

=cut

sub absolute {
    my ( $self, $base ) = @_;
    return $self if $self->is_absolute;
    return path( join "/", $base // Cwd::getcwd, $_[0]->[PATH] );
}

=method append

    path("foo.txt")->append(@data);
    path("foo.txt")->append({binmode => ":raw"}, @data);

Appends data to a file.  The file is locked with C<flock> prior to writing.  An
optional hash reference may be used to pass options.  The only option is
C<binmode>, which is passed to C<binmode()> on the handle used for writing.

=cut

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

=method append_utf8

    path("foo.txt")->append_utf8(@data);

This is like C<append> with a C<binmode> of C<:encoding(UTF-8)>.

=cut

sub append_utf8 { unshift @_, { binmode => ":encoding(UTF-8)" }; goto &append }

=method basename

    path("foo/bar.txt")->basename; # bar.txt

Returns the file portion or last directory portion of a path.

=cut

sub basename {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[FILE];
    return $self->[FILE];
}

=method child

    $file = path("/tmp")->child("foo.txt"); # "/tmp/foo.txt"
    $file = path("/tmp")->child(@parts);

Returns a new C<Path::Tiny> object relative to the original.  Works
like C<catfile> or C<catdir> from File::Spec, but without caring about
file or directories.

=cut

sub child {
    my ( $self, @parts ) = @_;
    return path( join "/", $self->[PATH], @parts );
}

=method children

    @paths = path("/tmp")->children;

Returns a list of C<Path::Tiny> objects for all file and directories
within a directory.  Excludes "." and ".." automatically.

=cut

# XXX take a match parameter?  qr or coderef?
sub children {
    my ($self) = @_;
    opendir my $dh, $self->[PATH];
    return map { $self->child($_) } grep { $_ ne '.' && $_ ne '..' } readdir $dh;
}

=method copy

    path("/tmp/foo.txt")->copy("/tmp/bar.txt");

Copies a file using L<File::Copy>'s C<copy> function.

=cut

# XXX do recursively for directories?
sub copy { File::Copy::copy( $_[0]->[PATH], $_[1] ) or die "Copy failed: $!" }

=method dirname

    path("/tmp/foo.txt")->dirname; # "/tmp/"

Returns the directory name portion of the path.  This is roughly
equivalent to what L<File::Spec> would give from C<splitpath> and thus
usually has the trailing slash. If that's not desired, stringify directories
or call C<parent> on files.

=cut

sub dirname {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[DIR];
    return length $self->[DIR] ? $self->[DIR] : ".";
}

=method exists

    path("/tmp")->exists;

Just like C<-e>.

=cut

sub exists { -e $_[0]->[PATH] }

=method filehandle

    $fh = path("/tmp/foo.txt")->filehandle($mode, $binmode);

Returns a file handle.  The C<$mode> argument must be a Perl-style
read/write mode string ("<" ,">", "<<", etc.).  If a C<$binmode>
is given, it is passed to C<binmode> on the handle.

See L</openr>, L</openw>, L</openrw>, L</opena> for sugar.

=cut

sub filehandle {
    my ( $self, $mode, $binmode ) = @_;
    my $fh;
    if ( defined $self->[TEMP] ) {
        $fh = $self->[TEMP];
    }
    else {
        $mode //= "<";
        open $fh, $mode, $self->[PATH];
    }
    binmode( $fh, $binmode ) if $binmode;
    return $fh;
}

=method is_absolute

    if ( path("/tmp")->is_absolute ) { ... }

Boolean for whether the path appear absolute or not.

=cut

sub is_absolute { substr( $_[0]->dirname, 0, 1 ) eq '/' }

=method is_dir

    if ( path("/tmp")->is_dir ) { ... }

Just like C<-d>.

=cut

sub is_dir { -d $_[0]->[PATH] }

=method is_file

    if ( path("/tmp")->is_file ) { ... }

Just like C<-f>.

=cut

sub is_file { -f $_[0]->[PATH] }

=method is_relative

    if ( path("/tmp")->is_relative ) { ... }

Boolean for whether the path appear relative or not.

=cut

sub is_relative { substr( $_[0]->dirname, 0, 1 ) ne '/' }

=method iterator

    $iter = path("/tmp")->iterator;
    while ( $path = $iter->() ) {
        ...
    }

Returns a code reference that walks a directory lazily.  Each invocation
returns a C<Path::Tiny> object or undef when the iterator is exhausted.

=cut

sub iterator {
    my ($self) = @_;
    opendir( my $dh, $self->[PATH] );
    return sub {
        return unless $dh;
        my $next;
        while ( defined( $next = readdir $dh ) ) {
            return $self->child($next) if $next ne '.' && $next ne '..';
        }
        undef $dh;
        return;
    };
}

=method lines

    @contents = path("/tmp/foo.txt")->lines;
    @contents = path("/tmp/foo.txt")->lines(\%options);

Returns a list of lines from a file.  Optionally takes a hash-reference
of options.  Valid options are C<binmode> and C<chomp>.  If C<binmode> is
provided, it will be set on the handle prior to reading.  If C<chomp> is
set, lines will be chomped before being returned.

=cut

sub lines {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $fh    = $self->openr( $args->{binmode} );
    my $chomp = $args->{chomp};
    if ( $args->{count} ) {
        return map { chomp if $chomp; $_ } map { scalar <$fh> } 1 .. $args->{count};
    }
    else {
        return map { chomp if $chomp; $_ } <$fh>;
    }
}

=method lines_utf8

    @contents = path("/tmp/foo.txt")->lines_utf8;
    @contents = path("/tmp/foo.txt")->lines({chomp => 1});

This is like C<lines> with a C<binmode> of C<:encoding(UTF-8)>.

=cut

sub lines_utf8 {
    $_[1] = {} unless ref $_[1] eq 'HASH';
    $_[1]->{binmode} = ":encoding(UTF-8)";
    goto &lines;
}

=method lstat

TBD

=cut

sub lstat { File::stat::stat( $_[0]->[PATH] ) }

=method mkpath

TBD

=cut

sub mkpath {
    my ( $self, $opts ) = @_;
    return File::Path::make_path( $self->[PATH], ref($opts) eq 'HASH' ? $opts : () );
}

=method move

TBD

=cut

sub move { rename $_[0]->[PATH], $_[1] }

=method openr, openr_utf8, openw, openw_utf8, ...

    $fh = path("foo.txt")->openr($binmode);  # read
    $fh = path("foo.txt")->openr_utf8;

    $fh = path("foo.txt")->openw($binmode);  # write
    $fh = path("foo.txt")->openw_utf8;

    $fh = path("foo.txt")->opena($binmode);  # append
    $fh = path("foo.txt")->opena_utf8;

    $fh = path("foo.txt")->openrw($binmode); # read/write
    $fh = path("foo.txt")->openrw_utf8;

Returns a file handle opened in the specified mode.  The C<openr> style
methods take a single C<binmode> argument.  The C<openr_utf8> style methods
use C<:encoding(UTF-8)>.

=cut

my %opens = (
    opena  => ">>",
    openr  => "<",
    openw  => ">",
    openrw => "+<"
);

while ( my ( $k, $v ) = each %opens ) {
    *{$k} = sub { $_[0]->filehandle( $v, $_[1] ) };
    *{ $k . "_utf8" } = sub { $_[0]->filehandle( $v, ":encoding(UTF-8)" ) };
}

=method parent

TBD

=cut

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

=method relative

TBD

=cut

# Easy to get wrong, so wash it through File::Spec (sigh)
sub relative {
    my ( $self, $base ) = @_;
    return path( File::Spec->abs2rel( $self->[PATH], $base ) );
}

=method remove

TBD

=cut

sub remove {
    my ( $self, $opts ) = @_;
    if ( -d $self->[PATH] ) {
        return File::Path::remove_tree( $self->[PATH], ref($opts) eq 'HASH' ? $opts : () );
    }
    else {
        return ( -e $self->[PATH] ) ? unlink $self->[PATH] : 1;
    }
}

=method slurp

TBD

=cut 

sub slurp {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $fh = $self->openr( $args->{binmode} );
    local $/;
    return scalar <$fh>;
}

=method slurp_utf8

TBD

=cut

sub slurp_utf8 { unshift @_, { binmode => ":encoding(UTF-8)" }; goto &slurp }

=method spew

TBD

=cut

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

=method spew_utf8

TBD

=cut

sub spew_utf8 { unshift @_, { binmode => ":encoding(UTF-8)" }; goto &spew }

=method stat

TBD

=cut

# XXX break out individual stat() components as subs?
sub stat { File::stat::stat( $_[0]->[PATH] ) }

=method stringify

TBD

=cut

sub stringify { $_[0]->[PATH] }

=method touch

TBD

=cut

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

=method volume

TBD

=cut

sub volume {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[VOL];
    return $self->[VOL];
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  use Path::Tiny;

  my $dir = path("/tmp");
  my $subdir = $dir->child("foo");
  my $file = $subdir->child("bar.txt");

  ...

=head1 DESCRIPTION

This module attempts to provide a small, fast utility for working with
file paths.  It is friendlier to use than raw L<File::Spec> and provides
easy access to functions from several other core file handling modules.

It doesn't attempt to be as full-featured as L<IO::All> or L<Path::Class>,
nor does it try to work for anything except Unix-like and Win32 platforms.

It tries to be fast, with as minimal overhead over File::Spec as possible.

All paths are converted to Unix-style forward slashes.

=head1 SEE ALSO

=for :list
* L<File::Fu>
* L<IO::All>
* L<Path::Class>

Probably others.  Let me know if you want me to add some.

=cut

# vim: ts=4 sts=4 sw=4 et:
