use 5.008001;
use strict;
use warnings;

package Path::Tiny;
# ABSTRACT: File path utility

our $VERSION = '0.109';

# Dependencies
use Config;
use Exporter 5.57   (qw/import/);
use File::Spec 0.86 ();          # shipped with 5.8.1
use Carp ();

our @EXPORT    = qw/path/;
our @EXPORT_OK = qw/cwd rootdir tempfile tempdir/;

use constant {
    PATH     => 0,
    CANON    => 1,
    VOL      => 2,
    DIR      => 3,
    FILE     => 4,
    TEMP     => 5,
    IS_WIN32 => ( $^O eq 'MSWin32' ),
};

use overload (
    q{""}    => sub    { $_[0]->[PATH] },
    bool     => sub () { 1 },
    fallback => 1,
);

# FREEZE/THAW per Sereal/CBOR/Types::Serialiser protocol
sub FREEZE { return $_[0]->[PATH] }
sub THAW   { return path( $_[2] ) }
{ no warnings 'once'; *TO_JSON = *FREEZE };

my $HAS_UU; # has Unicode::UTF8; lazily populated

sub _check_UU {
    local $SIG{__DIE__}; # prevent outer handler from being called
    !!eval {
        require Unicode::UTF8;
        Unicode::UTF8->VERSION(0.58);
        1;
    };
}

my $HAS_PU;              # has PerlIO::utf8_strict; lazily populated

sub _check_PU {
    local $SIG{__DIE__}; # prevent outer handler from being called
    !!eval {
        # MUST preload Encode or $SIG{__DIE__} localization fails
        # on some Perl 5.8.8 (maybe other 5.8.*) compiled with -O2.
        require Encode;
        require PerlIO::utf8_strict;
        PerlIO::utf8_strict->VERSION(0.003);
        1;
    };
}

my $HAS_FLOCK = $Config{d_flock} || $Config{d_fcntl_can_lock} || $Config{d_lockf};

# notions of "root" directories differ on Win32: \\server\dir\ or C:\ or \
my $SLASH      = qr{[\\/]};
my $NOTSLASH   = qr{[^\\/]};
my $DRV_VOL    = qr{[a-z]:}i;
my $UNC_VOL    = qr{$SLASH $SLASH $NOTSLASH+ $SLASH $NOTSLASH+}x;
my $WIN32_ROOT = qr{(?: $UNC_VOL $SLASH | $DRV_VOL $SLASH | $SLASH )}x;

sub _win32_vol {
    my ( $path, $drv ) = @_;
    require Cwd;
    my $dcwd = eval { Cwd::getdcwd($drv) }; # C: -> C:\some\cwd
    # getdcwd on non-existent drive returns empty string
    # so just use the original drive Z: -> Z:
    $dcwd = "$drv" unless defined $dcwd && length $dcwd;
    # normalize dwcd to end with a slash: might be C:\some\cwd or D:\ or Z:
    $dcwd =~ s{$SLASH?$}{/};
    # make the path absolute with dcwd
    $path =~ s{^$DRV_VOL}{$dcwd};
    return $path;
}

# This is a string test for before we have the object; see is_rootdir for well-formed
# object test
sub _is_root {
    return IS_WIN32() ? ( $_[0] =~ /^$WIN32_ROOT$/ ) : ( $_[0] eq '/' );
}

BEGIN {
    *_same = IS_WIN32() ? sub { lc( $_[0] ) eq lc( $_[1] ) } : sub { $_[0] eq $_[1] };
}

# mode bits encoded for chmod in symbolic mode
my %MODEBITS = ( om => 0007, gm => 0070, um => 0700 ); ## no critic
{ my $m = 0; $MODEBITS{$_} = ( 1 << $m++ ) for qw/ox ow or gx gw gr ux uw ur/ };

sub _symbolic_chmod {
    my ( $mode, $symbolic ) = @_;
    for my $clause ( split /,\s*/, $symbolic ) {
        if ( $clause =~ m{\A([augo]+)([=+-])([rwx]+)\z} ) {
            my ( $who, $action, $perms ) = ( $1, $2, $3 );
            $who =~ s/a/ugo/g;
            for my $w ( split //, $who ) {
                my $p = 0;
                $p |= $MODEBITS{"$w$_"} for split //, $perms;
                if ( $action eq '=' ) {
                    $mode = ( $mode & ~$MODEBITS{"${w}m"} ) | $p;
                }
                else {
                    $mode = $action eq "+" ? ( $mode | $p ) : ( $mode & ~$p );
                }
            }
        }
        else {
            Carp::croak("Invalid mode clause '$clause' for chmod()");
        }
    }
    return $mode;
}

# flock doesn't work on NFS on BSD or on some filesystems like lustre.
# Since program authors often can't control or detect that, we warn once
# instead of being fatal if we can detect it and people who need it strict
# can fatalize the 'flock' category

#<<< No perltidy
{ package flock; use warnings::register }
#>>>

my $WARNED_NO_FLOCK = 0;

sub _throw {
    my ( $self, $function, $file, $msg ) = @_;
    if (   $function =~ /^flock/
        && $! =~ /operation not supported|function not implemented/i
        && !warnings::fatal_enabled('flock') )
    {
        if ( !$WARNED_NO_FLOCK ) {
            warnings::warn( flock => "Flock not available: '$!': continuing in unsafe mode" );
            $WARNED_NO_FLOCK++;
        }
    }
    else {
        $msg = $! unless defined $msg;
        Path::Tiny::Error->throw( $function, ( defined $file ? $file : $self->[PATH] ),
            $msg );
    }
    return;
}

# cheapo option validation
sub _get_args {
    my ( $raw, @valid ) = @_;
    if ( defined($raw) && ref($raw) ne 'HASH' ) {
        my ( undef, undef, undef, $called_as ) = caller(1);
        $called_as =~ s{^.*::}{};
        Carp::croak("Options for $called_as must be a hash reference");
    }
    my $cooked = {};
    for my $k (@valid) {
        $cooked->{$k} = delete $raw->{$k} if exists $raw->{$k};
    }
    if ( keys %$raw ) {
        my ( undef, undef, undef, $called_as ) = caller(1);
        $called_as =~ s{^.*::}{};
        Carp::croak( "Invalid option(s) for $called_as: " . join( ", ", keys %$raw ) );
    }
    return $cooked;
}

#--------------------------------------------------------------------------#
# Constructors
#--------------------------------------------------------------------------#

=construct path

    $path = path("foo/bar");
    $path = path("/tmp", "file.txt"); # list
    $path = path(".");                # cwd
    $path = path("~user/file.txt");   # tilde processing

Constructs a C<Path::Tiny> object.  It doesn't matter if you give a file or
directory path.  It's still up to you to call directory-like methods only on
directories and file-like methods only on files.  This function is exported
automatically by default.

The first argument must be defined and have non-zero length or an exception
will be thrown.  This prevents subtle, dangerous errors with code like
C<< path( maybe_undef() )->remove_tree >>.

If the first component of the path is a tilde ('~') then the component will be
replaced with the output of C<glob('~')>.  If the first component of the path
is a tilde followed by a user name then the component will be replaced with
output of C<glob('~username')>.  Behaviour for non-existent users depends on
the output of C<glob> on the system.

On Windows, if the path consists of a drive identifier without a path component
(C<C:> or C<D:>), it will be expanded to the absolute path of the current
directory on that volume using C<Cwd::getdcwd()>.

If called with a single C<Path::Tiny> argument, the original is returned unless
the original is holding a temporary file or directory reference in which case a
stringified copy is made.

    $path = path("foo/bar");
    $temp = Path::Tiny->tempfile;

    $p2 = path($path); # like $p2 = $path
    $t2 = path($temp); # like $t2 = path( "$temp" )

This optimizes copies without proliferating references unexpectedly if a copy is
made by code outside your control.

Current API available since 0.017.

=cut

sub path {
    my $path = shift;
    Carp::croak("Path::Tiny paths require defined, positive-length parts")
      unless 1 + @_ == grep { defined && length } $path, @_;

    # non-temp Path::Tiny objects are effectively immutable and can be reused
    if ( !@_ && ref($path) eq __PACKAGE__ && !$path->[TEMP] ) {
        return $path;
    }

    # stringify objects
    $path = "$path";

    # expand relative volume paths on windows; put trailing slash on UNC root
    if ( IS_WIN32() ) {
        $path = _win32_vol( $path, $1 ) if $path =~ m{^($DRV_VOL)(?:$NOTSLASH|$)};
        $path .= "/" if $path =~ m{^$UNC_VOL$};
    }

    # concatenations stringifies objects, too
    if (@_) {
        $path .= ( _is_root($path) ? "" : "/" ) . join( "/", @_ );
    }

    # canonicalize, but with unix slashes and put back trailing volume slash
    my $cpath = $path = File::Spec->canonpath($path);
    $path =~ tr[\\][/] if IS_WIN32();
    $path = "/" if $path eq '/..'; # for old File::Spec
    $path .= "/" if IS_WIN32() && $path =~ m{^$UNC_VOL$};

    # root paths must always have a trailing slash, but other paths must not
    if ( _is_root($path) ) {
        $path =~ s{/?$}{/};
    }
    else {
        $path =~ s{/$}{};
    }

    # do any tilde expansions
    if ( $path =~ m{^(~[^/]*).*} ) {
        require File::Glob;
        my ($homedir) = File::Glob::bsd_glob($1);
        $homedir =~ tr[\\][/] if IS_WIN32();
        $path =~ s{^(~[^/]*)}{$homedir};
    }

    bless [ $path, $cpath ], __PACKAGE__;
}

=construct new

    $path = Path::Tiny->new("foo/bar");

This is just like C<path>, but with method call overhead.  (Why would you
do that?)

Current API available since 0.001.

=cut

sub new { shift; path(@_) }

=construct cwd

    $path = Path::Tiny->cwd; # path( Cwd::getcwd )
    $path = cwd; # optional export

Gives you the absolute path to the current directory as a C<Path::Tiny> object.
This is slightly faster than C<< path(".")->absolute >>.

C<cwd> may be exported on request and used as a function instead of as a
method.

Current API available since 0.018.

=cut

sub cwd {
    require Cwd;
    return path( Cwd::getcwd() );
}

=construct rootdir

    $path = Path::Tiny->rootdir; # /
    $path = rootdir;             # optional export 

Gives you C<< File::Spec->rootdir >> as a C<Path::Tiny> object if you're too
picky for C<path("/")>.

C<rootdir> may be exported on request and used as a function instead of as a
method.

Current API available since 0.018.

=cut

sub rootdir { path( File::Spec->rootdir ) }

=construct tempfile, tempdir

    $temp = Path::Tiny->tempfile( @options );
    $temp = Path::Tiny->tempdir( @options );
    $temp = tempfile( @options ); # optional export
    $temp = tempdir( @options );  # optional export

C<tempfile> passes the options to C<< File::Temp->new >> and returns a C<Path::Tiny>
object with the file name.  The C<TMPDIR> option is enabled by default.

The resulting C<File::Temp> object is cached. When the C<Path::Tiny> object is
destroyed, the C<File::Temp> object will be as well.

C<File::Temp> annoyingly requires you to specify a custom template in slightly
different ways depending on which function or method you call, but
C<Path::Tiny> lets you ignore that and can take either a leading template or a
C<TEMPLATE> option and does the right thing.

    $temp = Path::Tiny->tempfile( "customXXXXXXXX" );             # ok
    $temp = Path::Tiny->tempfile( TEMPLATE => "customXXXXXXXX" ); # ok

The tempfile path object will be normalized to have an absolute path, even if
created in a relative directory using C<DIR>.  If you want it to have
the C<realpath> instead, pass a leading options hash like this:

    $real_temp = tempfile({realpath => 1}, @options);

C<tempdir> is just like C<tempfile>, except it calls
C<< File::Temp->newdir >> instead.

Both C<tempfile> and C<tempdir> may be exported on request and used as
functions instead of as methods.

B<Note>: for tempfiles, the filehandles from File::Temp are closed and not
reused.  This is not as secure as using File::Temp handles directly, but is
less prone to deadlocks or access problems on some platforms.  Think of what
C<Path::Tiny> gives you to be just a temporary file B<name> that gets cleaned
up.

B<Note 2>: if you don't want these cleaned up automatically when the object
is destroyed, File::Temp requires different options for directories and
files.  Use C<< CLEANUP => 0 >> for directories and C<< UNLINK => 0 >> for
files.

B<Note 3>: Don't lose the temporary object by chaining a method call instead
of storing it:

    my $lost = tempdir()->child("foo"); # tempdir cleaned up right away

B<Note 4>: The cached object may be accessed with the L</cached_temp> method.
Keeping a reference to, or modifying the cached object may break the
behavior documented above and is not supported.  Use at your own risk.

Current API available since 0.097.

=cut

sub tempfile {
    shift if @_ && $_[0] eq 'Path::Tiny'; # called as method
    my $opts = ( @_ && ref $_[0] eq 'HASH' ) ? shift @_ : {};
    $opts = _get_args( $opts, qw/realpath/ );

    my ( $maybe_template, $args ) = _parse_file_temp_args(@_);
    # File::Temp->new demands TEMPLATE
    $args->{TEMPLATE} = $maybe_template->[0] if @$maybe_template;

    require File::Temp;
    my $temp = File::Temp->new( TMPDIR => 1, %$args );
    close $temp;
    my $self = $opts->{realpath} ? path($temp)->realpath : path($temp)->absolute;
    $self->[TEMP] = $temp;                # keep object alive while we are
    return $self;
}

sub tempdir {
    shift if @_ && $_[0] eq 'Path::Tiny'; # called as method
    my $opts = ( @_ && ref $_[0] eq 'HASH' ) ? shift @_ : {};
    $opts = _get_args( $opts, qw/realpath/ );

    my ( $maybe_template, $args ) = _parse_file_temp_args(@_);

    # File::Temp->newdir demands leading template
    require File::Temp;
    my $temp = File::Temp->newdir( @$maybe_template, TMPDIR => 1, %$args );
    my $self = $opts->{realpath} ? path($temp)->realpath : path($temp)->absolute;
    $self->[TEMP] = $temp;                # keep object alive while we are
    # Some ActiveState Perls for Windows break Cwd in ways that lead
    # File::Temp to get confused about what path to remove; this
    # monkey-patches the object with our own view of the absolute path
    $temp->{REALNAME} = $self->[CANON] if IS_WIN32;
    return $self;
}

# normalize the various ways File::Temp does templates
sub _parse_file_temp_args {
    my $leading_template = ( scalar(@_) % 2 == 1 ? shift(@_) : '' );
    my %args = @_;
    %args = map { uc($_), $args{$_} } keys %args;
    my @template = (
          exists $args{TEMPLATE} ? delete $args{TEMPLATE}
        : $leading_template      ? $leading_template
        :                          ()
    );
    return ( \@template, \%args );
}

#--------------------------------------------------------------------------#
# Private methods
#--------------------------------------------------------------------------#

sub _splitpath {
    my ($self) = @_;
    @{$self}[ VOL, DIR, FILE ] = File::Spec->splitpath( $self->[PATH] );
}

sub _resolve_symlinks {
    my ($self) = @_;
    my $new = $self;
    my ( $count, %seen ) = 0;
    while ( -l $new->[PATH] ) {
        if ( $seen{ $new->[PATH] }++ ) {
            $self->_throw( 'readlink', $self->[PATH], "symlink loop detected" );
        }
        if ( ++$count > 100 ) {
            $self->_throw( 'readlink', $self->[PATH], "maximum symlink depth exceeded" );
        }
        my $resolved = readlink $new->[PATH] or $new->_throw( 'readlink', $new->[PATH] );
        $resolved = path($resolved);
        $new = $resolved->is_absolute ? $resolved : $new->sibling($resolved);
    }
    return $new;
}

#--------------------------------------------------------------------------#
# Public methods
#--------------------------------------------------------------------------#

=method absolute

    $abs = path("foo/bar")->absolute;
    $abs = path("foo/bar")->absolute("/tmp");

Returns a new C<Path::Tiny> object with an absolute path (or itself if already
absolute).  If no argument is given, the current directory is used as the
absolute base path.  If an argument is given, it will be converted to an
absolute path (if it is not already) and used as the absolute base path.

This will not resolve upward directories ("foo/../bar") unless C<canonpath>
in L<File::Spec> would normally do so on your platform.  If you need them
resolved, you must call the more expensive C<realpath> method instead.

On Windows, an absolute path without a volume component will have it added
based on the current drive.

Current API available since 0.101.

=cut

sub absolute {
    my ( $self, $base ) = @_;

    # absolute paths handled differently by OS
    if (IS_WIN32) {
        return $self if length $self->volume;
        # add missing volume
        if ( $self->is_absolute ) {
            require Cwd;
            # use Win32::GetCwd not Cwd::getdcwd because we're sure
            # to have the former but not necessarily the latter
            my ($drv) = Win32::GetCwd() =~ /^($DRV_VOL | $UNC_VOL)/x;
            return path( $drv . $self->[PATH] );
        }
    }
    else {
        return $self if $self->is_absolute;
    }

    # no base means use current directory as base
    require Cwd;
    return path( Cwd::getcwd(), $_[0]->[PATH] ) unless defined $base;

    # relative base should be made absolute; we check is_absolute rather
    # than unconditionally make base absolute so that "/foo" doesn't become
    # "C:/foo" on Windows.
    $base = path($base);
    return path( ( $base->is_absolute ? $base : $base->absolute ), $_[0]->[PATH] );
}

=method append, append_raw, append_utf8

    path("foo.txt")->append(@data);
    path("foo.txt")->append(\@data);
    path("foo.txt")->append({binmode => ":raw"}, @data);
    path("foo.txt")->append_raw(@data);
    path("foo.txt")->append_utf8(@data);

Appends data to a file.  The file is locked with C<flock> prior to writing
and closed afterwards.  An optional hash reference may be used to pass
options.  Valid options are:

=for :list
* C<binmode>: passed to C<binmode()> on the handle used for writing.
* C<truncate>: truncates the file after locking and before appending

The C<truncate> option is a way to replace the contents of a file
B<in place>, unlike L</spew> which writes to a temporary file and then
replaces the original (if it exists).

C<append_raw> is like C<append> with a C<binmode> of C<:unix> for fast,
unbuffered, raw write.

C<append_utf8> is like C<append> with a C<binmode> of
C<:unix:encoding(UTF-8)> (or L<PerlIO::utf8_strict>).  If L<Unicode::UTF8>
0.58+ is installed, a raw append will be done instead on the data encoded
with C<Unicode::UTF8>.

Current API available since 0.060.

=cut

sub append {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode truncate/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;
    my $mode = $args->{truncate} ? ">" : ">>";
    my $fh = $self->filehandle( { locked => 1 }, $mode, $binmode );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    close $fh or $self->_throw('close');
}

sub append_raw {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode truncate/ );
    $args->{binmode} = ':unix';
    append( $self, $args, @data );
}

sub append_utf8 {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode truncate/ );
    if ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) ) {
        $args->{binmode} = ":unix";
        append( $self, $args, map { Unicode::UTF8::encode_utf8($_) } @data );
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        $args->{binmode} = ":unix:utf8_strict";
        append( $self, $args, @data );
    }
    else {
        $args->{binmode} = ":unix:encoding(UTF-8)";
        append( $self, $args, @data );
    }
}

=method assert

    $path = path("foo.txt")->assert( sub { $_->exists } );

Returns the invocant after asserting that a code reference argument returns
true.  When the assertion code reference runs, it will have the invocant
object in the C<$_> variable.  If it returns false, an exception will be
thrown.  The assertion code reference may also throw its own exception.

If no assertion is provided, the invocant is returned without error.

Current API available since 0.062.

=cut

sub assert {
    my ( $self, $assertion ) = @_;
    return $self unless $assertion;
    if ( ref $assertion eq 'CODE' ) {
        local $_ = $self;
        $assertion->()
          or Path::Tiny::Error->throw( "assert", $self->[PATH], "failed assertion" );
    }
    else {
        Carp::croak("argument to assert must be a code reference argument");
    }
    return $self;
}

=method basename

    $name = path("foo/bar.txt")->basename;        # bar.txt
    $name = path("foo.txt")->basename('.txt');    # foo
    $name = path("foo.txt")->basename(qr/.txt/);  # foo
    $name = path("foo.txt")->basename(@suffixes);

Returns the file portion or last directory portion of a path.

Given a list of suffixes as strings or regular expressions, any that match at
the end of the file portion or last directory portion will be removed before
the result is returned.

Current API available since 0.054.

=cut

sub basename {
    my ( $self, @suffixes ) = @_;
    $self->_splitpath unless defined $self->[FILE];
    my $file = $self->[FILE];
    for my $s (@suffixes) {
        my $re = ref($s) eq 'Regexp' ? qr/$s$/ : qr/\Q$s\E$/;
        last if $file =~ s/$re//;
    }
    return $file;
}

=method canonpath

    $canonical = path("foo/bar")->canonpath; # foo\bar on Windows

Returns a string with the canonical format of the path name for
the platform.  In particular, this means directory separators
will be C<\> on Windows.

Current API available since 0.001.

=cut

sub canonpath { $_[0]->[CANON] }

=method cached_temp

Returns the cached C<File::Temp> or C<File::Temp::Dir> object if the
C<Path::Tiny> object was created with C</tempfile> or C</tempdir>.
If there is no such object, this method throws.

B<WARNING>: Keeping a reference to, or modifying the cached object may
break the behavior documented for temporary files and directories created
with C<Path::Tiny> and is not supported.  Use at your own risk.

Current API available since 0.101.

=cut

sub cached_temp {
    my $self = shift;
    $self->_throw( "cached_temp", $self, "has no cached File::Temp object" )
      unless defined $self->[TEMP];
    return $self->[TEMP];
}

=method child

    $file = path("/tmp")->child("foo.txt"); # "/tmp/foo.txt"
    $file = path("/tmp")->child(@parts);

Returns a new C<Path::Tiny> object relative to the original.  Works
like C<catfile> or C<catdir> from File::Spec, but without caring about
file or directories.

B<WARNING>: because the argument could contain C<..> or refer to symlinks,
there is no guarantee that the new path refers to an actual descendent of
the original.  If this is important to you, transform parent and child with
L</realpath> and check them with L</subsumes>.

Current API available since 0.001.

=cut

sub child {
    my ( $self, @parts ) = @_;
    return path( $self->[PATH], @parts );
}

=method children

    @paths = path("/tmp")->children;
    @paths = path("/tmp")->children( qr/\.txt$/ );

Returns a list of C<Path::Tiny> objects for all files and directories
within a directory.  Excludes "." and ".." automatically.

If an optional C<qr//> argument is provided, it only returns objects for child
names that match the given regular expression.  Only the base name is used
for matching:

    @paths = path("/tmp")->children( qr/^foo/ );
    # matches children like the glob foo*

Current API available since 0.028.

=cut

sub children {
    my ( $self, $filter ) = @_;
    my $dh;
    opendir $dh, $self->[PATH] or $self->_throw('opendir');
    my @children = readdir $dh;
    closedir $dh or $self->_throw('closedir');

    if ( not defined $filter ) {
        @children = grep { $_ ne '.' && $_ ne '..' } @children;
    }
    elsif ( $filter && ref($filter) eq 'Regexp' ) {
        @children = grep { $_ ne '.' && $_ ne '..' && $_ =~ $filter } @children;
    }
    else {
        Carp::croak("Invalid argument '$filter' for children()");
    }

    return map { path( $self->[PATH], $_ ) } @children;
}

=method chmod

    path("foo.txt")->chmod(0777);
    path("foo.txt")->chmod("0755");
    path("foo.txt")->chmod("go-w");
    path("foo.txt")->chmod("a=r,u+wx");

Sets file or directory permissions.  The argument can be a numeric mode, a
octal string beginning with a "0" or a limited subset of the symbolic mode use
by F</bin/chmod>.

The symbolic mode must be a comma-delimited list of mode clauses.  Clauses must
match C<< qr/\A([augo]+)([=+-])([rwx]+)\z/ >>, which defines "who", "op" and
"perms" parameters for each clause.  Unlike F</bin/chmod>, all three parameters
are required for each clause, multiple ops are not allowed and permissions
C<stugoX> are not supported.  (See L<File::chmod> for more complex needs.)

Current API available since 0.053.

=cut

sub chmod {
    my ( $self, $new_mode ) = @_;

    my $mode;
    if ( $new_mode =~ /\d/ ) {
        $mode = ( $new_mode =~ /^0/ ? oct($new_mode) : $new_mode );
    }
    elsif ( $new_mode =~ /[=+-]/ ) {
        $mode = _symbolic_chmod( $self->stat->mode & 07777, $new_mode ); ## no critic
    }
    else {
        Carp::croak("Invalid mode argument '$new_mode' for chmod()");
    }

    CORE::chmod( $mode, $self->[PATH] ) or $self->_throw("chmod");

    return 1;
}

=method copy

    path("/tmp/foo.txt")->copy("/tmp/bar.txt");

Copies the current path to the given destination using L<File::Copy>'s
C<copy> function. Upon success, returns the C<Path::Tiny> object for the
newly copied file.

Current API available since 0.070.

=cut

# XXX do recursively for directories?
sub copy {
    my ( $self, $dest ) = @_;
    require File::Copy;
    File::Copy::copy( $self->[PATH], $dest )
      or Carp::croak("copy failed for $self to $dest: $!");

    return -d $dest ? path( $dest, $self->basename ) : path($dest);
}

=method digest

    $obj = path("/tmp/foo.txt")->digest;        # SHA-256
    $obj = path("/tmp/foo.txt")->digest("MD5"); # user-selected
    $obj = path("/tmp/foo.txt")->digest( { chunk_size => 1e6 }, "MD5" );

Returns a hexadecimal digest for a file.  An optional hash reference of options may
be given.  The only option is C<chunk_size>.  If C<chunk_size> is given, that many
bytes will be read at a time.  If not provided, the entire file will be slurped
into memory to compute the digest.

Any subsequent arguments are passed to the constructor for L<Digest> to select
an algorithm.  If no arguments are given, the default is SHA-256.

Current API available since 0.056.

=cut

sub digest {
    my ( $self, @opts ) = @_;
    my $args = ( @opts && ref $opts[0] eq 'HASH' ) ? shift @opts : {};
    $args = _get_args( $args, qw/chunk_size/ );
    unshift @opts, 'SHA-256' unless @opts;
    require Digest;
    my $digest = Digest->new(@opts);
    if ( $args->{chunk_size} ) {
        my $fh = $self->filehandle( { locked => 1 }, "<", ":unix" );
        my $buf;
        $digest->add($buf) while read $fh, $buf, $args->{chunk_size};
    }
    else {
        $digest->add( $self->slurp_raw );
    }
    return $digest->hexdigest;
}

=method dirname (deprecated)

    $name = path("/tmp/foo.txt")->dirname; # "/tmp/"

Returns the directory portion you would get from calling
C<< File::Spec->splitpath( $path->stringify ) >> or C<"."> for a path without a
parent directory portion.  Because L<File::Spec> is inconsistent, the result
might or might not have a trailing slash.  Because of this, this method is
B<deprecated>.

A better, more consistently approach is likely C<< $path->parent->stringify >>,
which will not have a trailing slash except for a root directory.

Deprecated in 0.056.

=cut

sub dirname {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[DIR];
    return length $self->[DIR] ? $self->[DIR] : ".";
}

=method edit, edit_raw, edit_utf8

    path("foo.txt")->edit( \&callback, $options );
    path("foo.txt")->edit_utf8( \&callback );
    path("foo.txt")->edit_raw( \&callback );

These are convenience methods that allow "editing" a file using a single
callback argument. They slurp the file using C<slurp>, place the contents
inside a localized C<$_> variable, call the callback function (without
arguments), and then write C<$_> (presumably mutated) back to the
file with C<spew>.

An optional hash reference may be used to pass options.  The only option is
C<binmode>, which is passed to C<slurp> and C<spew>.

C<edit_utf8> and C<edit_raw> act like their respective C<slurp_*> and
C<spew_*> methods.

Current API available since 0.077.

=cut

sub edit {
    my $self = shift;
    my $cb   = shift;
    my $args = _get_args( shift, qw/binmode/ );
    Carp::croak("Callback for edit() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';

    local $_ =
      $self->slurp( exists( $args->{binmode} ) ? { binmode => $args->{binmode} } : () );
    $cb->();
    $self->spew( $args, $_ );

    return;
}

# this is done long-hand to benefit from slurp_utf8 optimizations
sub edit_utf8 {
    my ( $self, $cb ) = @_;
    Carp::croak("Callback for edit_utf8() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';

    local $_ = $self->slurp_utf8;
    $cb->();
    $self->spew_utf8($_);

    return;
}

sub edit_raw { $_[2] = { binmode => ":unix" }; goto &edit }

=method edit_lines, edit_lines_utf8, edit_lines_raw

    path("foo.txt")->edit_lines( \&callback, $options );
    path("foo.txt")->edit_lines_utf8( \&callback );
    path("foo.txt")->edit_lines_raw( \&callback );

These are convenience methods that allow "editing" a file's lines using a
single callback argument.  They iterate over the file: for each line, the
line is put into a localized C<$_> variable, the callback function is
executed (without arguments) and then C<$_> is written to a temporary file.
When iteration is finished, the temporary file is atomically renamed over
the original.

An optional hash reference may be used to pass options.  The only option is
C<binmode>, which is passed to the method that open handles for reading and
writing.

C<edit_lines_utf8> and C<edit_lines_raw> act like their respective
C<slurp_*> and C<spew_*> methods.

Current API available since 0.077.

=cut

sub edit_lines {
    my $self = shift;
    my $cb   = shift;
    my $args = _get_args( shift, qw/binmode/ );
    Carp::croak("Callback for edit_lines() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';

    my $binmode = $args->{binmode};
    # get default binmode from caller's lexical scope (see "perldoc open")
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;

    # writing need to follow the link and create the tempfile in the same
    # dir for later atomic rename
    my $resolved_path = $self->_resolve_symlinks;
    my $temp          = path( $resolved_path . $$ . int( rand( 2**31 ) ) );

    my $temp_fh = $temp->filehandle( { exclusive => 1, locked => 1 }, ">", $binmode );
    my $in_fh = $self->filehandle( { locked => 1 }, '<', $binmode );

    local $_;
    while (<$in_fh>) {
        $cb->();
        $temp_fh->print($_);
    }

    close $temp_fh or $self->_throw( 'close', $temp );
    close $in_fh or $self->_throw('close');

    return $temp->move($resolved_path);
}

sub edit_lines_raw { $_[2] = { binmode => ":unix" }; goto &edit_lines }

sub edit_lines_utf8 {
    $_[2] = { binmode => ":raw:encoding(UTF-8)" };
    goto &edit_lines;
}

=method exists, is_file, is_dir

    if ( path("/tmp")->exists ) { ... }     # -e
    if ( path("/tmp")->is_dir ) { ... }     # -d
    if ( path("/tmp")->is_file ) { ... }    # -e && ! -d

Implements file test operations, this means the file or directory actually has
to exist on the filesystem.  Until then, it's just a path.

B<Note>: C<is_file> is not C<-f> because C<-f> is not the opposite of C<-d>.
C<-f> means "plain file", excluding symlinks, devices, etc. that often can be
read just like files.

Use C<-f> instead if you really mean to check for a plain file.

Current API available since 0.053.

=cut

sub exists { -e $_[0]->[PATH] }

sub is_file { -e $_[0]->[PATH] && !-d _ }

sub is_dir { -d $_[0]->[PATH] }

=method filehandle

    $fh = path("/tmp/foo.txt")->filehandle($mode, $binmode);
    $fh = path("/tmp/foo.txt")->filehandle({ locked => 1 }, $mode, $binmode);
    $fh = path("/tmp/foo.txt")->filehandle({ exclusive => 1  }, $mode, $binmode);

Returns an open file handle.  The C<$mode> argument must be a Perl-style
read/write mode string ("<" ,">", ">>", etc.).  If a C<$binmode>
is given, it is set during the C<open> call.

An optional hash reference may be used to pass options.

The C<locked> option governs file locking; if true, handles opened for writing,
appending or read-write are locked with C<LOCK_EX>; otherwise, they are
locked with C<LOCK_SH>.  When using C<locked>, ">" or "+>" modes will delay
truncation until after the lock is acquired.

The C<exclusive> option causes the open() call to fail if the file already
exists.  This corresponds to the O_EXCL flag to sysopen / open(2).
C<exclusive> implies C<locked> and will set it for you if you forget it.

See C<openr>, C<openw>, C<openrw>, and C<opena> for sugar.

Current API available since 0.066.

=cut

# Note: must put binmode on open line, not subsequent binmode() call, so things
# like ":unix" actually stop perlio/crlf from being added

sub filehandle {
    my ( $self, @args ) = @_;
    my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
    $args = _get_args( $args, qw/locked exclusive/ );
    $args->{locked} = 1 if $args->{exclusive};
    my ( $opentype, $binmode ) = @args;

    $opentype = "<" unless defined $opentype;
    Carp::croak("Invalid file mode '$opentype'")
      unless grep { $opentype eq $_ } qw/< +< > +> >> +>>/;

    $binmode = ( ( caller(0) )[10] || {} )->{ 'open' . substr( $opentype, -1, 1 ) }
      unless defined $binmode;
    $binmode = "" unless defined $binmode;

    my ( $fh, $lock, $trunc );
    if ( $HAS_FLOCK && $args->{locked} && !$ENV{PERL_PATH_TINY_NO_FLOCK} ) {
        require Fcntl;
        # truncating file modes shouldn't truncate until lock acquired
        if ( grep { $opentype eq $_ } qw( > +> ) ) {
            # sysopen in write mode without truncation
            my $flags = $opentype eq ">" ? Fcntl::O_WRONLY() : Fcntl::O_RDWR();
            $flags |= Fcntl::O_CREAT();
            $flags |= Fcntl::O_EXCL() if $args->{exclusive};
            sysopen( $fh, $self->[PATH], $flags ) or $self->_throw("sysopen");

            # fix up the binmode since sysopen() can't specify layers like
            # open() and binmode() can't start with just :unix like open()
            if ( $binmode =~ s/^:unix// ) {
                # eliminate pseudo-layers
                binmode( $fh, ":raw" ) or $self->_throw("binmode (:raw)");
                # strip off real layers until only :unix is left
                while ( 1 < ( my $layers =()= PerlIO::get_layers( $fh, output => 1 ) ) ) {
                    binmode( $fh, ":pop" ) or $self->_throw("binmode (:pop)");
                }
            }

            # apply any remaining binmode layers
            if ( length $binmode ) {
                binmode( $fh, $binmode ) or $self->_throw("binmode ($binmode)");
            }

            # ask for lock and truncation
            $lock  = Fcntl::LOCK_EX();
            $trunc = 1;
        }
        elsif ( $^O eq 'aix' && $opentype eq "<" ) {
            # AIX can only lock write handles, so upgrade to RW and LOCK_EX if
            # the file is writable; otherwise give up on locking.  N.B.
            # checking -w before open to determine the open mode is an
            # unavoidable race condition
            if ( -w $self->[PATH] ) {
                $opentype = "+<";
                $lock     = Fcntl::LOCK_EX();
            }
        }
        else {
            $lock = $opentype eq "<" ? Fcntl::LOCK_SH() : Fcntl::LOCK_EX();
        }
    }

    unless ($fh) {
        my $mode = $opentype . $binmode;
        open $fh, $mode, $self->[PATH] or $self->_throw("open ($mode)");
    }

    do { flock( $fh, $lock ) or $self->_throw("flock ($lock)") } if $lock;
    do { truncate( $fh, 0 ) or $self->_throw("truncate") } if $trunc;

    return $fh;
}

=method is_absolute, is_relative

    if ( path("/tmp")->is_absolute ) { ... }
    if ( path("/tmp")->is_relative ) { ... }

Booleans for whether the path appears absolute or relative.

Current API available since 0.001.

=cut

sub is_absolute { substr( $_[0]->dirname, 0, 1 ) eq '/' }

sub is_relative { substr( $_[0]->dirname, 0, 1 ) ne '/' }

=method is_rootdir

    while ( ! $path->is_rootdir ) {
        $path = $path->parent;
        ...
    }

Boolean for whether the path is the root directory of the volume.  I.e. the
C<dirname> is C<q[/]> and the C<basename> is C<q[]>.

This works even on C<MSWin32> with drives and UNC volumes:

    path("C:/")->is_rootdir;             # true
    path("//server/share/")->is_rootdir; #true

Current API available since 0.038.

=cut

sub is_rootdir {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[DIR];
    return $self->[DIR] eq '/' && $self->[FILE] eq '';
}

=method iterator

    $iter = path("/tmp")->iterator( \%options );

Returns a code reference that walks a directory lazily.  Each invocation
returns a C<Path::Tiny> object or undef when the iterator is exhausted.

    $iter = path("/tmp")->iterator;
    while ( $path = $iter->() ) {
        ...
    }

The current and parent directory entries ("." and "..") will not
be included.

If the C<recurse> option is true, the iterator will walk the directory
recursively, breadth-first.  If the C<follow_symlinks> option is also true,
directory links will be followed recursively.  There is no protection against
loops when following links. If a directory is not readable, it will not be
followed.

The default is the same as:

    $iter = path("/tmp")->iterator( {
        recurse         => 0,
        follow_symlinks => 0,
    } );

For a more powerful, recursive iterator with built-in loop avoidance, see
L<Path::Iterator::Rule>.

See also L</visit>.

Current API available since 0.016.

=cut

sub iterator {
    my $self = shift;
    my $args = _get_args( shift, qw/recurse follow_symlinks/ );
    my @dirs = $self;
    my $current;
    return sub {
        my $next;
        while (@dirs) {
            if ( ref $dirs[0] eq 'Path::Tiny' ) {
                if ( !-r $dirs[0] ) {
                    # Directory is missing or not readable, so skip it.  There
                    # is still a race condition possible between the check and
                    # the opendir, but we can't easily differentiate between
                    # error cases that are OK to skip and those that we want
                    # to be exceptions, so we live with the race and let opendir
                    # be fatal.
                    shift @dirs and next;
                }
                $current = $dirs[0];
                my $dh;
                opendir( $dh, $current->[PATH] )
                  or $self->_throw( 'opendir', $current->[PATH] );
                $dirs[0] = $dh;
                if ( -l $current->[PATH] && !$args->{follow_symlinks} ) {
                    # Symlink attack! It was a real dir, but is now a symlink!
                    # N.B. we check *after* opendir so the attacker has to win
                    # two races: replace dir with symlink before opendir and
                    # replace symlink with dir before -l check above
                    shift @dirs and next;
                }
            }
            while ( defined( $next = readdir $dirs[0] ) ) {
                next if $next eq '.' || $next eq '..';
                my $path = $current->child($next);
                push @dirs, $path
                  if $args->{recurse} && -d $path && !( !$args->{follow_symlinks} && -l $path );
                return $path;
            }
            shift @dirs;
        }
        return;
    };
}

=method lines, lines_raw, lines_utf8

    @contents = path("/tmp/foo.txt")->lines;
    @contents = path("/tmp/foo.txt")->lines(\%options);
    @contents = path("/tmp/foo.txt")->lines_raw;
    @contents = path("/tmp/foo.txt")->lines_utf8;

    @contents = path("/tmp/foo.txt")->lines( { chomp => 1, count => 4 } );

Returns a list of lines from a file.  Optionally takes a hash-reference of
options.  Valid options are C<binmode>, C<count> and C<chomp>.

If C<binmode> is provided, it will be set on the handle prior to reading.

If a positive C<count> is provided, that many lines will be returned from the
start of the file.  If a negative C<count> is provided, the entire file will be
read, but only C<abs(count)> will be kept and returned.  If C<abs(count)>
exceeds the number of lines in the file, all lines will be returned.

If C<chomp> is set, any end-of-line character sequences (C<CR>, C<CRLF>, or
C<LF>) will be removed from the lines returned.

Because the return is a list, C<lines> in scalar context will return the number
of lines (and throw away the data).

    $number_of_lines = path("/tmp/foo.txt")->lines;

C<lines_raw> is like C<lines> with a C<binmode> of C<:raw>.  We use C<:raw>
instead of C<:unix> so PerlIO buffering can manage reading by line.

C<lines_utf8> is like C<lines> with a C<binmode> of C<:raw:encoding(UTF-8)>
(or L<PerlIO::utf8_strict>).  If L<Unicode::UTF8> 0.58+ is installed, a raw
UTF-8 slurp will be done and then the lines will be split.  This is
actually faster than relying on C<:encoding(UTF-8)>, though a bit memory
intensive.  If memory use is a concern, consider C<openr_utf8> and
iterating directly on the handle.

Current API available since 0.065.

=cut

sub lines {
    my $self    = shift;
    my $args    = _get_args( shift, qw/binmode chomp count/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open<'} unless defined $binmode;
    my $fh = $self->filehandle( { locked => 1 }, "<", $binmode );
    my $chomp = $args->{chomp};
    # XXX more efficient to read @lines then chomp(@lines) vs map?
    if ( $args->{count} ) {
        my ( $counter, $mod, @result ) = ( 0, abs( $args->{count} ) );
        while ( my $line = <$fh> ) {
            $line =~ s/(?:\x{0d}?\x{0a}|\x{0d})$// if $chomp;
            $result[ $counter++ ] = $line;
            # for positive count, terminate after right number of lines
            last if $counter == $args->{count};
            # for negative count, eventually wrap around in the result array
            $counter %= $mod;
        }
        # reorder results if full and wrapped somewhere in the middle
        splice( @result, 0, 0, splice( @result, $counter ) )
          if @result == $mod && $counter % $mod;
        return @result;
    }
    elsif ($chomp) {
        return map { s/(?:\x{0d}?\x{0a}|\x{0d})$//; $_ } <$fh>; ## no critic
    }
    else {
        return wantarray ? <$fh> : ( my $count =()= <$fh> );
    }
}

sub lines_raw {
    my $self = shift;
    my $args = _get_args( shift, qw/binmode chomp count/ );
    if ( $args->{chomp} && !$args->{count} ) {
        return split /\n/, slurp_raw($self);                    ## no critic
    }
    else {
        $args->{binmode} = ":raw";
        return lines( $self, $args );
    }
}

my $CRLF = qr/(?:\x{0d}?\x{0a}|\x{0d})/;

sub lines_utf8 {
    my $self = shift;
    my $args = _get_args( shift, qw/binmode chomp count/ );
    if (   ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) )
        && $args->{chomp}
        && !$args->{count} )
    {
        my $slurp = slurp_utf8($self);
        $slurp =~ s/$CRLF$//; # like chomp, but full CR?LF|CR
        return split $CRLF, $slurp, -1; ## no critic
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        $args->{binmode} = ":unix:utf8_strict";
        return lines( $self, $args );
    }
    else {
        $args->{binmode} = ":raw:encoding(UTF-8)";
        return lines( $self, $args );
    }
}

=method mkpath

    path("foo/bar/baz")->mkpath;
    path("foo/bar/baz")->mkpath( \%options );

Like calling C<make_path> from L<File::Path>.  An optional hash reference
is passed through to C<make_path>.  Errors will be trapped and an exception
thrown.  Returns the list of directories created or an empty list if
the directories already exist, just like C<make_path>.

Current API available since 0.001.

=cut

sub mkpath {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $err;
    $args->{error} = \$err unless defined $args->{error};
    require File::Path;
    my @dirs = File::Path::make_path( $self->[PATH], $args );
    if ( $err && @$err ) {
        my ( $file, $message ) = %{ $err->[0] };
        Carp::croak("mkpath failed for $file: $message");
    }
    return @dirs;
}

=method move

    path("foo.txt")->move("bar.txt");

Move the current path to the given destination path using Perl's
built-in L<rename|perlfunc/rename> function. Returns the result
of the C<rename> function (except it throws an exception if it fails).

Current API available since 0.001.

=cut

sub move {
    my ( $self, $dst ) = @_;

    return rename( $self->[PATH], $dst )
      || $self->_throw( 'rename', $self->[PATH] . "' -> '$dst" );
}

=method openr, openw, openrw, opena

    $fh = path("foo.txt")->openr($binmode);  # read
    $fh = path("foo.txt")->openr_raw;
    $fh = path("foo.txt")->openr_utf8;

    $fh = path("foo.txt")->openw($binmode);  # write
    $fh = path("foo.txt")->openw_raw;
    $fh = path("foo.txt")->openw_utf8;

    $fh = path("foo.txt")->opena($binmode);  # append
    $fh = path("foo.txt")->opena_raw;
    $fh = path("foo.txt")->opena_utf8;

    $fh = path("foo.txt")->openrw($binmode); # read/write
    $fh = path("foo.txt")->openrw_raw;
    $fh = path("foo.txt")->openrw_utf8;

Returns a file handle opened in the specified mode.  The C<openr> style methods
take a single C<binmode> argument.  All of the C<open*> methods have
C<open*_raw> and C<open*_utf8> equivalents that use C<:raw> and
C<:raw:encoding(UTF-8)>, respectively.

An optional hash reference may be used to pass options.  The only option is
C<locked>.  If true, handles opened for writing, appending or read-write are
locked with C<LOCK_EX>; otherwise, they are locked for C<LOCK_SH>.

    $fh = path("foo.txt")->openrw_utf8( { locked => 1 } );

See L</filehandle> for more on locking.

Current API available since 0.011.

=cut

# map method names to corresponding open mode
my %opens = (
    opena  => ">>",
    openr  => "<",
    openw  => ">",
    openrw => "+<"
);

while ( my ( $k, $v ) = each %opens ) {
    no strict 'refs';
    # must check for lexical IO mode hint
    *{$k} = sub {
        my ( $self, @args ) = @_;
        my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
        $args = _get_args( $args, qw/locked/ );
        my ($binmode) = @args;
        $binmode = ( ( caller(0) )[10] || {} )->{ 'open' . substr( $v, -1, 1 ) }
          unless defined $binmode;
        $self->filehandle( $args, $v, $binmode );
    };
    *{ $k . "_raw" } = sub {
        my ( $self, @args ) = @_;
        my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
        $args = _get_args( $args, qw/locked/ );
        $self->filehandle( $args, $v, ":raw" );
    };
    *{ $k . "_utf8" } = sub {
        my ( $self, @args ) = @_;
        my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
        $args = _get_args( $args, qw/locked/ );
        $self->filehandle( $args, $v, ":raw:encoding(UTF-8)" );
    };
}

=method parent

    $parent = path("foo/bar/baz")->parent; # foo/bar
    $parent = path("foo/wibble.txt")->parent; # foo

    $parent = path("foo/bar/baz")->parent(2); # foo

Returns a C<Path::Tiny> object corresponding to the parent directory of the
original directory or file. An optional positive integer argument is the number
of parent directories upwards to return.  C<parent> by itself is equivalent to
C<parent(1)>.

Current API available since 0.014.

=cut

# XXX this is ugly and coverage is incomplete.  I think it's there for windows
# so need to check coverage there and compare
sub parent {
    my ( $self, $level ) = @_;
    $level = 1 unless defined $level && $level > 0;
    $self->_splitpath unless defined $self->[FILE];
    my $parent;
    if ( length $self->[FILE] ) {
        if ( $self->[FILE] eq '.' || $self->[FILE] eq ".." ) {
            $parent = path( $self->[PATH] . "/.." );
        }
        else {
            $parent = path( _non_empty( $self->[VOL] . $self->[DIR] ) );
        }
    }
    elsif ( length $self->[DIR] ) {
        # because of symlinks, any internal updir requires us to
        # just add more updirs at the end
        if ( $self->[DIR] =~ m{(?:^\.\./|/\.\./|/\.\.$)} ) {
            $parent = path( $self->[VOL] . $self->[DIR] . "/.." );
        }
        else {
            ( my $dir = $self->[DIR] ) =~ s{/[^\/]+/$}{/};
            $parent = path( $self->[VOL] . $dir );
        }
    }
    else {
        $parent = path( _non_empty( $self->[VOL] ) );
    }
    return $level == 1 ? $parent : $parent->parent( $level - 1 );
}

sub _non_empty {
    my ($string) = shift;
    return ( ( defined($string) && length($string) ) ? $string : "." );
}

=method closest

    $parent = path("foo/bar/baz")->closest("foo"); # foo
    $parent = path("foo/bar/baz")->closest("baz"); # bar
    
    $parent = path("foo/bar/baz")->closest("other"); # 0
    $parent = path("foo/bar/baz")->closest("other", "other/dir"); # other/dir

Returns a C<Path::Tiny> object corresponding to the parent directory matching the searched pattern from the
original directory or file. Returning undef if not found. An optional default path argument can be provided if none is found. 

Current API available since 0.109.

=cut

sub closest {
    my ( $self, $needle, $default ) = @_;
    
    return $self unless ( $needle ); # just return self if no search if performed
    
    my $path = $self->absolute->parent;

     # self checking loop
    while ( ! $path->is_rootdir ) {
        
        return $path if ( $path->basename eq $needle  );
        
        $path = $path->parent;
    }
    
    return ( $default ) ? path( $default ) : 0;

}

=method realpath

    $real = path("/baz/foo/../bar")->realpath;
    $real = path("foo/../bar")->realpath;

Returns a new C<Path::Tiny> object with all symbolic links and upward directory
parts resolved using L<Cwd>'s C<realpath>.  Compared to C<absolute>, this is
more expensive as it must actually consult the filesystem.

If the parent path can't be resolved (e.g. if it includes directories that
don't exist), an exception will be thrown:

    $real = path("doesnt_exist/foo")->realpath; # dies

However, if the parent path exists and only the last component (e.g. filename)
doesn't exist, the realpath will be the realpath of the parent plus the
non-existent last component:

    $real = path("./aasdlfasdlf")->realpath; # works

The underlying L<Cwd> module usually worked this way on Unix, but died on
Windows (and some Unixes) if the full path didn't exist.  As of version 0.064,
it's safe to use anywhere.

Current API available since 0.001.

=cut

# Win32 and some Unixes need parent path resolved separately so realpath
# doesn't throw an error resolving non-existent basename
sub realpath {
    my $self = shift;
    $self = $self->_resolve_symlinks;
    require Cwd;
    $self->_splitpath if !defined $self->[FILE];
    my $check_parent =
      length $self->[FILE] && $self->[FILE] ne '.' && $self->[FILE] ne '..';
    my $realpath = eval {
        # pure-perl Cwd can carp
        local $SIG{__WARN__} = sub { };
        Cwd::realpath( $check_parent ? $self->parent->[PATH] : $self->[PATH] );
    };
    # parent realpath must exist; not all Cwd::realpath will error if it doesn't
    $self->_throw("resolving realpath")
      unless defined $realpath && length $realpath && -e $realpath;
    return ( $check_parent ? path( $realpath, $self->[FILE] ) : path($realpath) );
}

=method relative

    $rel = path("/tmp/foo/bar")->relative("/tmp"); # foo/bar

Returns a C<Path::Tiny> object with a path relative to a new base path
given as an argument.  If no argument is given, the current directory will
be used as the new base path.

If either path is already relative, it will be made absolute based on the
current directly before determining the new relative path.

The algorithm is roughly as follows:

=for :list
* If the original and new base path are on different volumes, an exception
  will be thrown.
* If the original and new base are identical, the relative path is C<".">.
* If the new base subsumes the original, the relative path is the original
  path with the new base chopped off the front
* If the new base does not subsume the original, a common prefix path is
  determined (possibly the root directory) and the relative path will
  consist of updirs (C<"..">) to reach the common prefix, followed by the
  original path less the common prefix.

Unlike C<File::Spec::abs2rel>, in the last case above, the calculation based
on a common prefix takes into account symlinks that could affect the updir
process.  Given an original path "/A/B" and a new base "/A/C",
(where "A", "B" and "C" could each have multiple path components):

=for :list
* Symlinks in "A" don't change the result unless the last component of A is
  a symlink and the first component of "C" is an updir.
* Symlinks in "B" don't change the result and will exist in the result as
  given.
* Symlinks and updirs in "C" must be resolved to actual paths, taking into
  account the possibility that not all path components might exist on the
  filesystem.

Current API available since 0.001.  New algorithm (that accounts for
symlinks) available since 0.079.

=cut

sub relative {
    my ( $self, $base ) = @_;
    $base = path( defined $base && length $base ? $base : '.' );

    # relative paths must be converted to absolute first
    $self = $self->absolute if $self->is_relative;
    $base = $base->absolute if $base->is_relative;

    # normalize volumes if they exist
    $self = $self->absolute if !length $self->volume && length $base->volume;
    $base = $base->absolute if length $self->volume  && !length $base->volume;

    # can't make paths relative across volumes
    if ( !_same( $self->volume, $base->volume ) ) {
        Carp::croak("relative() can't cross volumes: '$self' vs '$base'");
    }

    # if same absolute path, relative is current directory
    return path(".") if _same( $self->[PATH], $base->[PATH] );

    # if base is a prefix of self, chop prefix off self
    if ( $base->subsumes($self) ) {
        $base = "" if $base->is_rootdir;
        my $relative = "$self";
        $relative =~ s{\A\Q$base/}{};
        return path($relative);
    }

    # base is not a prefix, so must find a common prefix (even if root)
    my ( @common, @self_parts, @base_parts );
    @base_parts = split /\//, $base->_just_filepath;

    # if self is rootdir, then common directory is root (shown as empty
    # string for later joins); otherwise, must be computed from path parts.
    if ( $self->is_rootdir ) {
        @common = ("");
        shift @base_parts;
    }
    else {
        @self_parts = split /\//, $self->_just_filepath;

        while ( @self_parts && @base_parts && _same( $self_parts[0], $base_parts[0] ) ) {
            push @common, shift @base_parts;
            shift @self_parts;
        }
    }

    # if there are any symlinks from common to base, we have a problem, as
    # you can't guarantee that updir from base reaches the common prefix;
    # we must resolve symlinks and try again; likewise, any updirs are
    # a problem as it throws off calculation of updirs needed to get from
    # self's path to the common prefix.
    if ( my $new_base = $self->_resolve_between( \@common, \@base_parts ) ) {
        return $self->relative($new_base);
    }

    # otherwise, symlinks in common or from common to A don't matter as
    # those don't involve updirs
    my @new_path = ( ("..") x ( 0+ @base_parts ), @self_parts );
    return path(@new_path);
}

sub _just_filepath {
    my $self     = shift;
    my $self_vol = $self->volume;
    return "$self" if !length $self_vol;

    ( my $self_path = "$self" ) =~ s{\A\Q$self_vol}{};

    return $self_path;
}

sub _resolve_between {
    my ( $self, $common, $base ) = @_;
    my $path = $self->volume . join( "/", @$common );
    my $changed = 0;
    for my $p (@$base) {
        $path .= "/$p";
        if ( $p eq '..' ) {
            $changed = 1;
            if ( -e $path ) {
                $path = path($path)->realpath->[PATH];
            }
            else {
                $path =~ s{/[^/]+/..$}{/};
            }
        }
        if ( -l $path ) {
            $changed = 1;
            $path    = path($path)->realpath->[PATH];
        }
    }
    return $changed ? path($path) : undef;
}

=method remove

    path("foo.txt")->remove;

This is just like C<unlink>, except for its error handling: if the path does
not exist, it returns false; if deleting the file fails, it throws an
exception.

Current API available since 0.012.

=cut

sub remove {
    my $self = shift;

    return 0 if !-e $self->[PATH] && !-l $self->[PATH];

    return unlink( $self->[PATH] ) || $self->_throw('unlink');
}

=method remove_tree

    # directory
    path("foo/bar/baz")->remove_tree;
    path("foo/bar/baz")->remove_tree( \%options );
    path("foo/bar/baz")->remove_tree( { safe => 0 } ); # force remove

Like calling C<remove_tree> from L<File::Path>, but defaults to C<safe> mode.
An optional hash reference is passed through to C<remove_tree>.  Errors will be
trapped and an exception thrown.  Returns the number of directories deleted,
just like C<remove_tree>.

If you want to remove a directory only if it is empty, use the built-in
C<rmdir> function instead.

    rmdir path("foo/bar/baz/");

Current API available since 0.013.

=cut

sub remove_tree {
    my ( $self, $args ) = @_;
    return 0 if !-e $self->[PATH] && !-l $self->[PATH];
    $args = {} unless ref $args eq 'HASH';
    my $err;
    $args->{error} = \$err unless defined $args->{error};
    $args->{safe}  = 1     unless defined $args->{safe};
    require File::Path;
    my $count = File::Path::remove_tree( $self->[PATH], $args );

    if ( $err && @$err ) {
        my ( $file, $message ) = %{ $err->[0] };
        Carp::croak("remove_tree failed for $file: $message");
    }
    return $count;
}

=method sibling

    $foo = path("/tmp/foo.txt");
    $sib = $foo->sibling("bar.txt");        # /tmp/bar.txt
    $sib = $foo->sibling("baz", "bam.txt"); # /tmp/baz/bam.txt

Returns a new C<Path::Tiny> object relative to the parent of the original.
This is slightly more efficient than C<< $path->parent->child(...) >>.

Current API available since 0.058.

=cut

sub sibling {
    my $self = shift;
    return path( $self->parent->[PATH], @_ );
}

=method slurp, slurp_raw, slurp_utf8

    $data = path("foo.txt")->slurp;
    $data = path("foo.txt")->slurp( {binmode => ":raw"} );
    $data = path("foo.txt")->slurp_raw;
    $data = path("foo.txt")->slurp_utf8;

Reads file contents into a scalar.  Takes an optional hash reference which may
be used to pass options.  The only available option is C<binmode>, which is
passed to C<binmode()> on the handle used for reading.

C<slurp_raw> is like C<slurp> with a C<binmode> of C<:unix> for
a fast, unbuffered, raw read.

C<slurp_utf8> is like C<slurp> with a C<binmode> of
C<:unix:encoding(UTF-8)> (or L<PerlIO::utf8_strict>).  If L<Unicode::UTF8>
0.58+ is installed, a raw slurp will be done instead and the result decoded
with C<Unicode::UTF8>.  This is just as strict and is roughly an order of
magnitude faster than using C<:encoding(UTF-8)>.

B<Note>: C<slurp> and friends lock the filehandle before slurping.  If
you plan to slurp from a file created with L<File::Temp>, be sure to
close other handles or open without locking to avoid a deadlock:

    my $tempfile = File::Temp->new(EXLOCK => 0);
    my $guts = path($tempfile)->slurp;

Current API available since 0.004.

=cut

sub slurp {
    my $self    = shift;
    my $args    = _get_args( shift, qw/binmode/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open<'} unless defined $binmode;
    my $fh = $self->filehandle( { locked => 1 }, "<", $binmode );
    if ( ( defined($binmode) ? $binmode : "" ) eq ":unix"
        and my $size = -s $fh )
    {
        my $buf;
        read $fh, $buf, $size; # File::Slurp in a nutshell
        return $buf;
    }
    else {
        local $/;
        return scalar <$fh>;
    }
}

sub slurp_raw { $_[1] = { binmode => ":unix" }; goto &slurp }

sub slurp_utf8 {
    if ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) ) {
        return Unicode::UTF8::decode_utf8( slurp( $_[0], { binmode => ":unix" } ) );
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        $_[1] = { binmode => ":unix:utf8_strict" };
        goto &slurp;
    }
    else {
        $_[1] = { binmode => ":raw:encoding(UTF-8)" };
        goto &slurp;
    }
}

=method spew, spew_raw, spew_utf8

    path("foo.txt")->spew(@data);
    path("foo.txt")->spew(\@data);
    path("foo.txt")->spew({binmode => ":raw"}, @data);
    path("foo.txt")->spew_raw(@data);
    path("foo.txt")->spew_utf8(@data);

Writes data to a file atomically.  The file is written to a temporary file in
the same directory, then renamed over the original.  An optional hash reference
may be used to pass options.  The only option is C<binmode>, which is passed to
C<binmode()> on the handle used for writing.

C<spew_raw> is like C<spew> with a C<binmode> of C<:unix> for a fast,
unbuffered, raw write.

C<spew_utf8> is like C<spew> with a C<binmode> of C<:unix:encoding(UTF-8)>
(or L<PerlIO::utf8_strict>).  If L<Unicode::UTF8> 0.58+ is installed, a raw
spew will be done instead on the data encoded with C<Unicode::UTF8>.

B<NOTE>: because the file is written to a temporary file and then renamed, the
new file will wind up with permissions based on your current umask.  This is a
feature to protect you from a race condition that would otherwise give
different permissions than you might expect.  If you really want to keep the
original mode flags, use L</append> with the C<truncate> option.

Current API available since 0.011.

=cut

# XXX add "unsafe" option to disable flocking and atomic?  Check benchmarks on append() first.
sub spew {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode/ );
    my $binmode = $args->{binmode};
    # get default binmode from caller's lexical scope (see "perldoc open")
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;

    # spewing need to follow the link
    # and create the tempfile in the same dir
    my $resolved_path = $self->_resolve_symlinks;

    my $temp = path( $resolved_path . $$ . int( rand( 2**31 ) ) );
    my $fh = $temp->filehandle( { exclusive => 1, locked => 1 }, ">", $binmode );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    close $fh or $self->_throw( 'close', $temp->[PATH] );

    return $temp->move($resolved_path);
}

sub spew_raw { splice @_, 1, 0, { binmode => ":unix" }; goto &spew }

sub spew_utf8 {
    if ( defined($HAS_UU) ? $HAS_UU : ( $HAS_UU = _check_UU() ) ) {
        my $self = shift;
        spew(
            $self,
            { binmode => ":unix" },
            map { Unicode::UTF8::encode_utf8($_) } map { ref eq 'ARRAY' ? @$_ : $_ } @_
        );
    }
    elsif ( defined($HAS_PU) ? $HAS_PU : ( $HAS_PU = _check_PU() ) ) {
        splice @_, 1, 0, { binmode => ":unix:utf8_strict" };
        goto &spew;
    }
    else {
        splice @_, 1, 0, { binmode => ":unix:encoding(UTF-8)" };
        goto &spew;
    }
}

=method stat, lstat

    $stat = path("foo.txt")->stat;
    $stat = path("/some/symlink")->lstat;

Like calling C<stat> or C<lstat> from L<File::stat>.

Current API available since 0.001.

=cut

# XXX break out individual stat() components as subs?
sub stat {
    my $self = shift;
    require File::stat;
    return File::stat::stat( $self->[PATH] ) || $self->_throw('stat');
}

sub lstat {
    my $self = shift;
    require File::stat;
    return File::stat::lstat( $self->[PATH] ) || $self->_throw('lstat');
}

=method stringify

    $path = path("foo.txt");
    say $path->stringify; # same as "$path"

Returns a string representation of the path.  Unlike C<canonpath>, this method
returns the path standardized with Unix-style C</> directory separators.

Current API available since 0.001.

=cut

sub stringify { $_[0]->[PATH] }

=method subsumes

    path("foo/bar")->subsumes("foo/bar/baz"); # true
    path("/foo/bar")->subsumes("/foo/baz");   # false

Returns true if the first path is a prefix of the second path at a directory
boundary.

This B<does not> resolve parent directory entries (C<..>) or symlinks:

    path("foo/bar")->subsumes("foo/bar/../baz"); # true

If such things are important to you, ensure that both paths are resolved to
the filesystem with C<realpath>:

    my $p1 = path("foo/bar")->realpath;
    my $p2 = path("foo/bar/../baz")->realpath;
    if ( $p1->subsumes($p2) ) { ... }

Current API available since 0.048.

=cut

sub subsumes {
    my $self = shift;
    Carp::croak("subsumes() requires a defined, positive-length argument")
      unless defined $_[0];
    my $other = path(shift);

    # normalize absolute vs relative
    if ( $self->is_absolute && !$other->is_absolute ) {
        $other = $other->absolute;
    }
    elsif ( $other->is_absolute && !$self->is_absolute ) {
        $self = $self->absolute;
    }

    # normalize volume vs non-volume; do this after absolute path
    # adjustments above since that might add volumes already
    if ( length $self->volume && !length $other->volume ) {
        $other = $other->absolute;
    }
    elsif ( length $other->volume && !length $self->volume ) {
        $self = $self->absolute;
    }

    if ( $self->[PATH] eq '.' ) {
        return !!1; # cwd subsumes everything relative
    }
    elsif ( $self->is_rootdir ) {
        # a root directory ("/", "c:/") already ends with a separator
        return $other->[PATH] =~ m{^\Q$self->[PATH]\E};
    }
    else {
        # exact match or prefix breaking at a separator
        return $other->[PATH] =~ m{^\Q$self->[PATH]\E(?:/|$)};
    }
}

=method touch

    path("foo.txt")->touch;
    path("foo.txt")->touch($epoch_secs);

Like the Unix C<touch> utility.  Creates the file if it doesn't exist, or else
changes the modification and access times to the current time.  If the first
argument is the epoch seconds then it will be used.

Returns the path object so it can be easily chained with other methods:

    # won't die if foo.txt doesn't exist
    $content = path("foo.txt")->touch->slurp;

Current API available since 0.015.

=cut

sub touch {
    my ( $self, $epoch ) = @_;
    if ( !-e $self->[PATH] ) {
        my $fh = $self->openw;
        close $fh or $self->_throw('close');
    }
    if ( defined $epoch ) {
        utime $epoch, $epoch, $self->[PATH]
          or $self->_throw("utime ($epoch)");
    }
    else {
        # literal undef prevents warnings :-(
        utime undef, undef, $self->[PATH]
          or $self->_throw("utime ()");
    }
    return $self;
}

=method touchpath

    path("bar/baz/foo.txt")->touchpath;

Combines C<mkpath> and C<touch>.  Creates the parent directory if it doesn't exist,
before touching the file.  Returns the path object like C<touch> does.

Current API available since 0.022.

=cut

sub touchpath {
    my ($self) = @_;
    my $parent = $self->parent;
    $parent->mkpath unless $parent->exists;
    $self->touch;
}

=method visit

    path("/tmp")->visit( \&callback, \%options );

Executes a callback for each child of a directory.  It returns a hash
reference with any state accumulated during iteration.

The options are the same as for L</iterator> (which it uses internally):
C<recurse> and C<follow_symlinks>.  Both default to false.

The callback function will receive a C<Path::Tiny> object as the first argument
and a hash reference to accumulate state as the second argument.  For example:

    # collect files sizes
    my $sizes = path("/tmp")->visit(
        sub {
            my ($path, $state) = @_;
            return if $path->is_dir;
            $state->{$path} = -s $path;
        },
        { recurse => 1 }
    );

For convenience, the C<Path::Tiny> object will also be locally aliased as the
C<$_> global variable:

    # print paths matching /foo/
    path("/tmp")->visit( sub { say if /foo/ }, { recurse => 1} );

If the callback returns a B<reference> to a false scalar value, iteration will
terminate.  This is not the same as "pruning" a directory search; this just
stops all iteration and returns the state hash reference.

    # find up to 10 files larger than 100K
    my $files = path("/tmp")->visit(
        sub {
            my ($path, $state) = @_;
            $state->{$path}++ if -s $path > 102400
            return \0 if keys %$state == 10;
        },
        { recurse => 1 }
    );

If you want more flexible iteration, use a module like L<Path::Iterator::Rule>.

Current API available since 0.062.

=cut

sub visit {
    my $self = shift;
    my $cb   = shift;
    my $args = _get_args( shift, qw/recurse follow_symlinks/ );
    Carp::croak("Callback for visit() must be a code reference")
      unless defined($cb) && ref($cb) eq 'CODE';
    my $next  = $self->iterator($args);
    my $state = {};
    while ( my $file = $next->() ) {
        local $_ = $file;
        my $r = $cb->( $file, $state );
        last if ref($r) eq 'SCALAR' && !$$r;
    }
    return $state;
}

=method volume

    $vol = path("/tmp/foo.txt")->volume;   # ""
    $vol = path("C:/tmp/foo.txt")->volume; # "C:"

Returns the volume portion of the path.  This is equivalent
to what L<File::Spec> would give from C<splitpath> and thus
usually is the empty string on Unix-like operating systems or the
drive letter for an absolute path on C<MSWin32>.

Current API available since 0.001.

=cut

sub volume {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[VOL];
    return $self->[VOL];
}

package Path::Tiny::Error;

our @CARP_NOT = qw/Path::Tiny/;

use overload ( q{""} => sub { (shift)->{msg} }, fallback => 1 );

sub throw {
    my ( $class, $op, $file, $err ) = @_;
    chomp( my $trace = Carp::shortmess );
    my $msg = "Error $op on '$file': $err$trace\n";
    die bless { op => $op, file => $file, err => $err, msg => $msg }, $class;
}

1;

=for Pod::Coverage
openr_utf8 opena_utf8 openw_utf8 openrw_utf8
openr_raw opena_raw openw_raw openrw_raw
IS_WIN32 FREEZE THAW TO_JSON abs2rel

=head1 SYNOPSIS

  use Path::Tiny;

  # creating Path::Tiny objects

  $dir = path("/tmp");
  $foo = path("foo.txt");

  $subdir = $dir->child("foo");
  $bar = $subdir->child("bar.txt");

  # stringifies as cleaned up path

  $file = path("./foo.txt");
  print $file; # "foo.txt"

  # reading files

  $guts = $file->slurp;
  $guts = $file->slurp_utf8;

  @lines = $file->lines;
  @lines = $file->lines_utf8;

  ($head) = $file->lines( {count => 1} );
  ($tail) = $file->lines( {count => -1} );

  # writing files

  $bar->spew( @data );
  $bar->spew_utf8( @data );

  # reading directories

  for ( $dir->children ) { ... }

  $iter = $dir->iterator;
  while ( my $next = $iter->() ) { ... }

=head1 DESCRIPTION

This module provides a small, fast utility for working with file paths.  It is
friendlier to use than L<File::Spec> and provides easy access to functions from
several other core file handling modules.  It aims to be smaller and faster
than many alternatives on CPAN, while helping people do many common things in
consistent and less error-prone ways.

Path::Tiny does not try to work for anything except Unix-like and Win32
platforms.  Even then, it might break if you try something particularly obscure
or tortuous.  (Quick!  What does this mean:
C<< ///../../..//./././a//b/.././c/././ >>?  And how does it differ on Win32?)

All paths are forced to have Unix-style forward slashes.  Stringifying
the object gives you back the path (after some clean up).

File input/output methods C<flock> handles before reading or writing,
as appropriate (if supported by the platform and/or filesystem).

The C<*_utf8> methods (C<slurp_utf8>, C<lines_utf8>, etc.) operate in raw
mode.  On Windows, that means they will not have CRLF translation from the
C<:crlf> IO layer.  Installing L<Unicode::UTF8> 0.58 or later will speed up
C<*_utf8> situations in many cases and is highly recommended.
Alternatively, installing L<PerlIO::utf8_strict> 0.003 or later will be
used in place of the default C<:encoding(UTF-8)>.

This module depends heavily on PerlIO layers for correct operation and thus
requires Perl 5.008001 or later.

=head1 EXCEPTION HANDLING

Simple usage errors will generally croak.  Failures of underlying Perl
functions will be thrown as exceptions in the class
C<Path::Tiny::Error>.

A C<Path::Tiny::Error> object will be a hash reference with the following fields:

=for :list
* C<op> — a description of the operation, usually function call and any extra info
* C<file> — the file or directory relating to the error
* C<err> — hold C<$!> at the time the error was thrown
* C<msg> — a string combining the above data and a Carp-like short stack trace

Exception objects will stringify as the C<msg> field.

=head1 ENVIRONMENT

=head2 PERL_PATH_TINY_NO_FLOCK

If the environment variable C<PERL_PATH_TINY_NO_FLOCK> is set to a true
value then flock will NOT be used when accessing files (this is not
recommended).

=head1 CAVEATS

=head2 Subclassing not supported

For speed, this class is implemented as an array based object and uses many
direct function calls internally.  You must not subclass it and expect
things to work properly.

=head2 File locking

If flock is not supported on a platform, it will not be used, even if
locking is requested.

In situations where a platform normally would support locking, but the
flock fails due to a filesystem limitation, Path::Tiny has some heuristics
to detect this and will warn once and continue in an unsafe mode.  If you
want this failure to be fatal, you can fatalize the 'flock' warnings
category:

    use warnings FATAL => 'flock';

See additional caveats below.

=head3 NFS and BSD

On BSD, Perl's flock implementation may not work to lock files on an
NFS filesystem.  If detected, this situation will warn once, as described
above.

=head3 Lustre

The Lustre filesystem does not support flock.  If detected, this situation
will warn once, as described above.

=head3 AIX and locking

AIX requires a write handle for locking.  Therefore, calls that normally
open a read handle and take a shared lock instead will open a read-write
handle and take an exclusive lock.  If the user does not have write
permission, no lock will be used.

=head2 utf8 vs UTF-8

All the C<*_utf8> methods by default use C<:encoding(UTF-8)> -- either as
C<:unix:encoding(UTF-8)> (unbuffered) or C<:raw:encoding(UTF-8)> (buffered) --
which is strict against the Unicode spec and disallows illegal Unicode
codepoints or UTF-8 sequences.

Unfortunately, C<:encoding(UTF-8)> is very, very slow.  If you install
L<Unicode::UTF8> 0.58 or later, that module will be used by some C<*_utf8>
methods to encode or decode data after a raw, binary input/output operation,
which is much faster.  Alternatively, if you install L<PerlIO::utf8_strict>,
that will be used instead of C<:encoding(UTF-8)> and is also very fast.

If you need the performance and can accept the security risk,
C<< slurp({binmode => ":unix:utf8"}) >> will be faster than C<:unix:encoding(UTF-8)>
(but not as fast as C<Unicode::UTF8>).

Note that the C<*_utf8> methods read in B<raw> mode.  There is no CRLF
translation on Windows.  If you must have CRLF translation, use the regular
input/output methods with an appropriate binmode:

  $path->spew_utf8($data);                            # raw
  $path->spew({binmode => ":encoding(UTF-8)"}, $data; # LF -> CRLF

=head2 Default IO layers and the open pragma

If you have Perl 5.10 or later, file input/output methods (C<slurp>, C<spew>,
etc.) and high-level handle opening methods ( C<filehandle>, C<openr>,
C<openw>, etc. ) respect default encodings set by the C<-C> switch or lexical
L<open> settings of the caller.  For UTF-8, this is almost certainly slower
than using the dedicated C<_utf8> methods if you have L<Unicode::UTF8>.

=head1 TYPE CONSTRAINTS AND COERCION

A standard L<MooseX::Types> library is available at
L<MooseX::Types::Path::Tiny>.  A L<Type::Tiny> equivalent is available as
L<Types::Path::Tiny>.

=head1 SEE ALSO

These are other file/path utilities, which may offer a different feature
set than C<Path::Tiny>.

=for :list
* L<File::chmod>
* L<File::Fu>
* L<IO::All>
* L<Path::Class>

These iterators may be slightly faster than the recursive iterator in
C<Path::Tiny>:

=for :list
* L<Path::Iterator::Rule>
* L<File::Next>

There are probably comparable, non-Tiny tools.  Let me know if you want me to
add a module to the list.

This module was featured in the L<2013 Perl Advent Calendar|http://www.perladvent.org/2013/2013-12-18.html>.

=cut

# vim: ts=4 sts=4 sw=4 et:
