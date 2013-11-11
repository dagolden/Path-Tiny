use 5.008001;
use strict;
use warnings;

package Path::Tiny;
# ABSTRACT: File path utility
# VERSION

# Dependencies
use Config;
use Exporter 5.57   (qw/import/);
use File::Spec 3.40 ();
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
    IS_BSD   => ( scalar $^O =~ /bsd$/ ),
    IS_WIN32 => ( $^O eq 'MSWin32' ),
};

use overload (
    q{""}    => sub    { $_[0]->[PATH] },
    bool     => sub () { 1 },
    fallback => 1,
);

# if cloning, threads should already be loaded, but Win32 pseudoforks
# don't do that so we have to be sure it's loaded anyway
my $TID = 0; # for thread safe atomic writes

sub CLONE { require threads; $TID = threads->tid }

my $HAS_UU;  # has Unicode::UTF8; lazily populated

sub _check_UU {
    eval { require Unicode::UTF8; Unicode::UTF8->VERSION(0.58); 1 };
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
    my $dcwd = Cwd::getdcwd($drv); # C: -> C:\some\cwd
    # getdcwd on non-existent drive returns empty string
    # so just use the original drive Z: -> Z:
    $dcwd = "$drv" unless length $dcwd;
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

# flock doesn't work on NFS on BSD.  Since program authors often can't control
# or detect that, we warn once instead of being fatal if we can detect it and
# people who need it strict can fatalize the 'flock' category

#<<< No perltidy
{ package flock; use if Path::Tiny::IS_BSD(), 'warnings::register' }
#>>>

my $WARNED_BSD_NFS = 0;

sub _throw {
    my ( $self, $function, $file ) = @_;
    if (   IS_BSD()
        && $function =~ /^flock/
        && $! =~ /operation not supported/i
        && !warnings::fatal_enabled('flock') )
    {
        if ( !$WARNED_BSD_NFS ) {
            warnings::warn( flock => "No flock for NFS on BSD: continuing in unsafe mode" );
            $WARNED_BSD_NFS++;
        }
    }
    else {
        Path::Tiny::Error->throw( $function, ( defined $file ? $file : $self->[PATH] ), $! );
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

=cut

sub path {
    my $path = shift;
    Carp::croak("path() requires a defined, positive-length argument")
      unless defined $path && length $path;

    # stringify initial path
    $path = "$path";

    # expand relative volume paths on windows; put trailing slash on UNC root
    if ( IS_WIN32() ) {
        $path = _win32_vol( $path, $1 ) if $path =~ m{^($DRV_VOL)(?:$NOTSLASH|$)};
        $path .= "/" if $path =~ m{^$UNC_VOL$};
    }

    # concatenate more arguments (stringifies any objects, too)
    if (@_) {
        $path .= ( _is_root($path) ? "" : "/" ) . join( "/", @_ );
    }

    # canonicalize paths
    my $cpath = $path = File::Spec->canonpath($path); # ugh, but probably worth it
    $path =~ tr[\\][/];                               # unix convention enforced
    $path .= "/" if IS_WIN32() && $path =~ m{^$UNC_VOL$}; # canonpath strips it

    # hack to make splitpath give us a basename; root paths must always have
    # a trailing slash, but other paths must not
    if ( _is_root($path) ) {
        $path =~ s{/?$}{/};
    }
    else {
        $path =~ s{/$}{};
    }

    # do any tilde expansions
    if ( $path =~ m{^(~[^/]*).*} ) {
        my ($homedir) = glob($1); # glob without list context == heisenbug!
        $path =~ s{^(~[^/]*)}{$homedir};
    }

    # and we're finally done
    bless [ $path, $cpath ], __PACKAGE__;
}

=construct new

    $path = Path::Tiny->new("foo/bar");

This is just like C<path>, but with method call overhead.  (Why would you
do that?)

=cut

sub new { shift; path(@_) }

=construct cwd

    $path = Path::Tiny->cwd; # path( Cwd::getcwd )
    $path = cwd; # optional export

Gives you the absolute path to the current directory as a C<Path::Tiny> object.
This is slightly faster than C<< path(".")->absolute >>.

C<cwd> may be exported on request and used as a function instead of as a
method.

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

The tempfile path object will normalized to have an absolute path, even if
created in a relative directory using C<DIR>.

C<tempdir> is just like C<tempfile>, except it calls
C<< File::Temp->newdir >> instead.

Both C<tempfile> and C<tempdir> may be exported on request and used as
functions instead of as methods.

=cut

sub tempfile {
    shift if $_[0] eq 'Path::Tiny'; # called as method
    my ( $maybe_template, $args ) = _parse_file_temp_args(@_);
    # File::Temp->new demands TEMPLATE
    $args->{TEMPLATE} = $maybe_template->[0] if @$maybe_template;

    require File::Temp;
    my $temp = File::Temp->new( TMPDIR => 1, %$args );
    close $temp;
    my $self = path($temp)->absolute;
    $self->[TEMP] = $temp;          # keep object alive while we are
    return $self;
}

sub tempdir {
    shift if $_[0] eq 'Path::Tiny'; # called as method
    my ( $maybe_template, $args ) = _parse_file_temp_args(@_);

    # File::Temp->newdir demands leading template
    require File::Temp;
    my $temp = File::Temp->newdir( @$maybe_template, TMPDIR => 1, %$args );
    my $self = path($temp)->absolute;
    $self->[TEMP] = $temp;          # keep object alive while we are
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

#--------------------------------------------------------------------------#
# Public methods
#--------------------------------------------------------------------------#

=method absolute

    $abs = path("foo/bar")->absolute;
    $abs = path("foo/bar")->absolute("/tmp");

Returns a new C<Path::Tiny> object with an absolute path (or itself if already
absolute).  Unless an argument is given, the current directory is used as the
absolute base path.  The argument must be absolute or you won't get an absolute
result.

This will not resolve upward directories ("foo/../bar") unless C<canonpath>
in L<File::Spec> would normally do so on your platform.  If you need them
resolved, you must call the more expensive C<realpath> method instead.

On Windows, an absolute path without a volume component will have it added
based on the current drive.

=cut

sub absolute {
    my ( $self, $base ) = @_;

    # absolute paths handled differently by OS
    if (IS_WIN32) {
        return $self if length $self->volume;
        # add missing volume
        if ( $self->is_absolute ) {
            require Cwd;
            my ($drv) = Cwd::getdcwd() =~ /^($DRV_VOL | $UNC_VOL)/x;
            return path( $drv . $self->[PATH] );
        }
    }
    else {
        return $self if $self->is_absolute;
    }

    # relative path on any OS
    require Cwd;
    return path( ( defined($base) ? $base : Cwd::getcwd() ), $_[0]->[PATH] );
}

=method append, append_raw, append_utf8

    path("foo.txt")->append(@data);
    path("foo.txt")->append(\@data);
    path("foo.txt")->append({binmode => ":raw"}, @data);
    path("foo.txt")->append_raw(@data);
    path("foo.txt")->append_utf8(@data);

Appends data to a file.  The file is locked with C<flock> prior to writing.  An
optional hash reference may be used to pass options.  The only option is
C<binmode>, which is passed to C<binmode()> on the handle used for writing.

C<append_raw> is like C<append> with a C<binmode> of C<:unix> for fast,
unbuffered, raw write.

C<append_utf8> is like C<append> with a C<binmode> of
C<:unix:encoding(UTF-8)>.  If L<Unicode::UTF8> 0.58+ is installed, a raw
append will be done instead on the data encoded with C<Unicode::UTF8>.

=cut

sub append {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode/ );
    my $binmode = $args->{binmode};
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;
    my $fh = $self->filehandle( { locked => 1 }, ">>", $binmode );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    close $fh or $self->_throw('close');
}

sub append_raw { splice @_, 1, 0, { binmode => ":unix" }; goto &append }

sub append_utf8 {
    if ( defined($HAS_UU) ? $HAS_UU : $HAS_UU = _check_UU() ) {
        my $self = shift;
        append( $self, { binmode => ":unix" }, map { Unicode::UTF8::encode_utf8($_) } @_ );
    }
    else {
        splice @_, 1, 0, { binmode => ":unix:encoding(UTF-8)" };
        goto &append;
    }
}

=method basename

    $name = path("foo/bar.txt")->basename; # bar.txt

Returns the file portion or last directory portion of a path.

=cut

sub basename {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[FILE];
    return $self->[FILE];
}

=method canonpath

    $canonical = path("foo/bar")->canonpath; # foo\bar on Windows

Returns a string with the canonical format of the path name for
the platform.  In particular, this means directory separators
will be C<\> on Windows.

=cut

sub canonpath { $_[0]->[CANON] }

=method child

    $file = path("/tmp")->child("foo.txt"); # "/tmp/foo.txt"
    $file = path("/tmp")->child(@parts);

Returns a new C<Path::Tiny> object relative to the original.  Works
like C<catfile> or C<catdir> from File::Spec, but without caring about
file or directories.

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

=method copy

    path("/tmp/foo.txt")->copy("/tmp/bar.txt");

Copies a file using L<File::Copy>'s C<copy> function.

=cut

# XXX do recursively for directories?
sub copy {
    my ( $self, $dest ) = @_;
    require File::Copy;
    File::Copy::copy( $self->[PATH], $dest )
      or Carp::croak("copy failed for $self to $dest: $!");
}

=method digest

    $obj = path("/tmp/foo.txt")->digest;        # SHA-256
    $obj = path("/tmp/foo.txt")->digest("MD5"); # user-selected

Returns a hexadecimal digest for a file.  Any arguments are passed to the
constructor for L<Digest> to select an algorithm.  If no arguments are given,
the default is SHA-256.

=cut

sub digest {
    my ( $self, $alg, @args ) = @_;
    $alg = 'SHA-256' unless defined $alg;
    require Digest;
    return Digest->new( $alg, @args )->add( $self->slurp_raw )->hexdigest;
}

=method dirname

    $name = path("/tmp/foo.txt")->dirname; # "/tmp/"

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

=method exists, is_file, is_dir

    if ( path("/tmp")->exists ) { ... }
    if ( path("/tmp")->is_file ) { ... }
    if ( path("/tmp")->is_dir ) { ... }

Just like C<-e>, C<-f> or C<-d>.  This means the file or directory actually has to
exist on the filesystem.  Until then, it's just a path.

=cut

sub exists { -e $_[0]->[PATH] }

sub is_file { -f $_[0]->[PATH] }

sub is_dir { -d $_[0]->[PATH] }

=method filehandle

    $fh = path("/tmp/foo.txt")->filehandle($mode, $binmode);
    $fh = path("/tmp/foo.txt")->filehandle({ locked => 1 }, $mode, $binmode);

Returns an open file handle.  The C<$mode> argument must be a Perl-style
read/write mode string ("<" ,">", "<<", etc.).  If a C<$binmode>
is given, it is set during the C<open> call.

An optional hash reference may be used to pass options.  The only option is
C<locked>.  If true, handles opened for writing, appending or read-write are
locked with C<LOCK_EX>; otherwise, they are locked with C<LOCK_SH>.  When using
C<locked>, ">" or "+>" modes will delay truncation until after the lock is
acquired.

See C<openr>, C<openw>, C<openrw>, and C<opena> for sugar.

=cut

# Note: must put binmode on open line, not subsequent binmode() call, so things
# like ":unix" actually stop perlio/crlf from being added

sub filehandle {
    my ( $self, @args ) = @_;
    my $args = ( @args && ref $args[0] eq 'HASH' ) ? shift @args : {};
    $args = _get_args( $args, qw/locked/ );
    my ( $opentype, $binmode ) = @args;

    $opentype = "<" unless defined $opentype;
    Carp::croak("Invalid file mode '$opentype'")
      unless grep { $opentype eq $_ } qw/< +< > +> >> +>>/;

    $binmode = ( ( caller(0) )[10] || {} )->{ 'open' . substr( $opentype, -1, 1 ) }
      unless defined $binmode;
    $binmode = "" unless defined $binmode;

    my ( $fh, $lock, $trunc );
    if ( $HAS_FLOCK && $args->{locked} ) {
        require Fcntl;
        # truncating file modes shouldn't truncate until lock acquired
        if ( grep { $opentype eq $_ } qw( > +> ) ) {
            # sysopen in write mode without truncation
            my $flags = $opentype eq ">" ? Fcntl::O_WRONLY() : Fcntl::O_RDWR();
            $flags |= Fcntl::O_CREAT();
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
            # AIX can only lock write handles, so upgrade to RW and LOCK_EX
            $opentype = "+<";
            $lock     = Fcntl::LOCK_EX();
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
loops when following links.

The default is the same as:

    $iter = path("/tmp")->iterator( {
        recurse         => 0,
        follow_symlinks => 0,
    } );

For a more powerful, recursive iterator with built-in loop avoidance, see
L<Path::Iterator::Rule>.

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
options.  Valid options are C<binmode>, C<count> and C<chomp>.  If C<binmode>
is provided, it will be set on the handle prior to reading.  If C<count> is
provided, up to that many lines will be returned. If C<chomp> is set, lines
will be chomped before being returned.

Because the return is a list, C<lines> in scalar context will return the number
of lines (and throw away the data).

    $number_of_lines = path("/tmp/foo.txt")->lines;

C<lines_raw> is like C<lines> with a C<binmode> of C<:raw>.  We use C<:raw>
instead of C<:unix> so PerlIO buffering can manage reading by line.

C<lines_utf8> is like C<lines> with a C<binmode> of
C<:raw:encoding(UTF-8)>.  If L<Unicode::UTF8> 0.58+ is installed, a raw
UTF-8 slurp will be done and then the lines will be split.  This is
actually faster than relying on C<:encoding(UTF-8)>, though a bit memory
intensive.  If memory use is a concern, consider C<openr_utf8> and
iterating directly on the handle.

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
        my ( @result, $counter );
        while ( my $line = <$fh> ) {
            chomp $line if $chomp;
            push @result, $line;
            last if ++$counter == $args->{count};
        }
        return @result;
    }
    elsif ($chomp) {
        return map { chomp; $_ } <$fh>;
    }
    else {
        return wantarray ? <$fh> : ( my $count =()= <$fh> );
    }
}

sub lines_raw {
    my $self = shift;
    my $args = _get_args( shift, qw/binmode chomp count/ );
    if ( $args->{chomp} && !$args->{count} ) {
        return split /\n/, slurp_raw($self); ## no critic
    }
    else {
        $args->{binmode} = ":raw";
        return lines( $self, $args );
    }
}

sub lines_utf8 {
    my $self = shift;
    my $args = _get_args( shift, qw/binmode chomp count/ );
    if (   ( defined($HAS_UU) ? $HAS_UU : $HAS_UU = _check_UU() )
        && $args->{chomp}
        && !$args->{count} )
    {
        return split /\n/, slurp_utf8($self); ## no critic
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

=cut

sub mkpath {
    my ( $self, $args ) = @_;
    $args = {} unless ref $args eq 'HASH';
    my $err;
    $args->{err} = \$err unless defined $args->{err};
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

Just like C<rename>.

=cut

sub move {
    my ( $self, $dst ) = @_;

    return rename( $self->[PATH], $dst )
      || $self->_throw( 'rename', $self->[PATH] . "' -> '$dst'" );
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

=method realpath

    $real = path("/baz/foo/../bar")->realpath;
    $real = path("foo/../bar")->realpath;

Returns a new C<Path::Tiny> object with all symbolic links and upward directory
parts resolved using L<Cwd>'s C<realpath>.  Compared to C<absolute>, this is
more expensive as it must actually consult the filesystem.

If the path can't be resolved (e.g. if it includes directories that don't exist),
an exception will be thrown:

    $real = path("doesnt_exist/foo")->realpath; # dies

=cut

sub realpath {
    my $self = shift;
    require Cwd;
    my $realpath = eval { Cwd::realpath( $self->[PATH] ) };
    $self->_throw("resolving realpath") unless defined $realpath and length $realpath;
    return path($realpath);
}

=method relative

    $rel = path("/tmp/foo/bar")->relative("/tmp"); # foo/bar

Returns a C<Path::Tiny> object with a relative path name.
Given the trickiness of this, it's a thin wrapper around
C<< File::Spec->abs2rel() >>.

=cut

# Easy to get wrong, so wash it through File::Spec (sigh)
sub relative { path( File::Spec->abs2rel( $_[0]->[PATH], $_[1] ) ) }

=method remove

    path("foo.txt")->remove;

B<Note: as of 0.012, remove only works on files>.

This is just like C<unlink>, except if the path does not exist, it returns
false rather than throwing an exception.

=cut

sub remove {
    my $self = shift;

    return 0 if !-e $self->[PATH] && !-l $self->[PATH];

    return unlink $self->[PATH] || $self->_throw('unlink');
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

=cut

sub remove_tree {
    my ( $self, $args ) = @_;
    return 0 if !-e $self->[PATH] && !-l $self->[PATH];
    $args = {} unless ref $args eq 'HASH';
    my $err;
    $args->{err}  = \$err unless defined $args->{err};
    $args->{safe} = 1     unless defined $args->{safe};
    require File::Path;
    my $count = File::Path::remove_tree( $self->[PATH], $args );

    if ( $err && @$err ) {
        my ( $file, $message ) = %{ $err->[0] };
        Carp::croak("remove_tree failed for $file: $message");
    }
    return $count;
}

=method slurp, slurp_raw, slurp_utf8

    $data = path("foo.txt")->slurp;
    $data = path("foo.txt")->slurp( {binmode => ":raw"} );
    $data = path("foo.txt")->slurp_raw;
    $data = path("foo.txt")->slurp_utf8;

Reads file contents into a scalar.  Takes an optional hash reference may be
used to pass options.  The only option is C<binmode>, which is passed to
C<binmode()> on the handle used for reading.

C<slurp_raw> is like C<slurp> with a C<binmode> of C<:unix> for
a fast, unbuffered, raw read.

C<slurp_utf8> is like C<slurp> with a C<binmode> of
C<:unix:encoding(UTF-8)>.  If L<Unicode::UTF8> 0.58+ is installed, a raw
slurp will be done instead and the result decoded with C<Unicode::UTF8>.
This is just as strict and is roughly an order of magnitude faster than
using C<:encoding(UTF-8)>.

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
    if ( defined($HAS_UU) ? $HAS_UU : $HAS_UU = _check_UU() ) {
        return Unicode::UTF8::decode_utf8( slurp( $_[0], { binmode => ":unix" } ) );
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

C<spew_utf8> is like C<spew> with a C<binmode> of C<:unix:encoding(UTF-8)>.
If L<Unicode::UTF8> 0.58+ is installed, a raw spew will be done instead on
the data encoded with C<Unicode::UTF8>.

=cut

# XXX add "unsafe" option to disable flocking and atomic?  Check benchmarks on append() first.
sub spew {
    my ( $self, @data ) = @_;
    my $args = ( @data && ref $data[0] eq 'HASH' ) ? shift @data : {};
    $args = _get_args( $args, qw/binmode/ );
    my $binmode = $args->{binmode};
    # get default binmode from caller's lexical scope (see "perldoc open")
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;
    my $temp = path( $self->[PATH] . $TID . $$ );
    my $fh = $temp->filehandle( { locked => 1 }, ">", $binmode );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    close $fh or $self->_throw( 'close', $temp->[PATH] );

    # spewing need to follow the link
    # and replace the destination instead
    my $resolved_path = $self->[PATH];
    $resolved_path = readlink $resolved_path while -l $resolved_path;
    return $temp->move($resolved_path);
}

sub spew_raw { splice @_, 1, 0, { binmode => ":unix" }; goto &spew }

sub spew_utf8 {
    if ( defined($HAS_UU) ? $HAS_UU : $HAS_UU = _check_UU() ) {
        my $self = shift;
        spew( $self, { binmode => ":unix" }, map { Unicode::UTF8::encode_utf8($_) } @_ );
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

=cut

sub subsumes {
    my $self = shift;
    Carp::croak("subsumes() requires a defined, positive-length argument")
      unless defined $_[0];
    my $other = path(shift);

    if ( $self->is_absolute && !$other->is_absolute ) {
        $other = $other->absolute;
    }
    elsif ( $other->is_absolute && !$self->is_absolute ) {
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

Returns the path object so it can be easily chained with spew:

    path("foo.txt")->touch->spew( $content );

=cut

sub touch {
    my ( $self, $epoch ) = @_;
    if ( !-e $self->[PATH] ) {
        my $fh = $self->openw;
        close $fh or $self->_throw('close');
    }
    $epoch = defined($epoch) ? $epoch : time();
    utime $epoch, $epoch, $self->[PATH]
      or $self->_throw("utime ($epoch)");
    return $self;
}

=method touchpath

    path("bar/baz/foo.txt")->touchpath;

Combines C<mkpath> and C<touch>.  Creates the parent directory if it doesn't exist,
before touching the file.  Returns the path object like C<touch> does.

=cut

sub touchpath {
    my ($self) = @_;
    my $parent = $self->parent;
    $parent->mkpath unless $parent->exists;
    $self->touch;
}

=method volume

    $vol = path("/tmp/foo.txt")->volume;   # ""
    $vol = path("C:/tmp/foo.txt")->volume; # "C:"

Returns the volume portion of the path.  This is equivalent
equivalent to what L<File::Spec> would give from C<splitpath> and thus
usually is the empty string on Unix-like operating systems or the
drive letter for an absolute path on C<MSWin32>.

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
IS_BSD IS_WIN32

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

  $head = $file->lines( {count => 1} );

  # writing files

  $bar->spew( @data );
  $bar->spew_utf8( @data );

  # reading directories

  for ( $dir->children ) { ... }

  $iter = $dir->iterator;
  while ( my $next = $iter->() ) { ... }

=head1 DESCRIPTION

This module attempts to provide a small, fast utility for working with
file paths.  It is friendlier to use than L<File::Spec> and provides
easy access to functions from several other core file handling modules.

It doesn't attempt to be as full-featured as L<IO::All> or L<Path::Class>,
nor does it try to work for anything except Unix-like and Win32 platforms.
Even then, it might break if you try something particularly obscure or
tortuous.  (Quick!  What does this mean: C<< ///../../..//./././a//b/.././c/././ >>?
And how does it differ on Win32?)

All paths are forced to have Unix-style forward slashes.  Stringifying
the object gives you back the path (after some clean up).

File input/output methods C<flock> handles before reading or writing,
as appropriate (if supported by the platform).

The C<*_utf8> methods (C<slurp_utf8>, C<lines_utf8>, etc.) operate in raw
mode without CRLF translation.  Installing L<Unicode::UTF8> 0.58 or later
will speed up several of them and is highly recommended.

=head1 EXCEPTION HANDLING

Failures will be thrown as exceptions in the class C<Path::Tiny::Error>.

The object will be a hash reference with the following fields:

=for :list
* C<op> — a description of the operation, usually function call and any extra info
* C<file> — the file or directory relating to the error
* C<err> — hold C<$!> at the time the error was thrown
* C<msg> — a string combining the above data and a Carp-like short stack trace

Exception objects will stringify as the C<msg> field.

=head1 CAVEATS

=head2 File locking

If flock is not supported on a platform, it will not be used, even if
locking is requested.

See additional caveats below.

=head3 NFS and BSD

On BSD, Perl's flock implementation may not work to lock files on an
NFS filesystem.  Path::Tiny has some heuristics to detect this
and will warn once and let you continue in an unsafe mode.  If you
want this failure to be fatal, you can fatalize the 'flock' warnings
category:

    use warnings FATAL => 'flock';

=head3 AIX and locking

AIX requires a write handle for locking.  Therefore, calls that normally
open a read handle and take a shared lock instead will open a read-write
handle and take an exclusive lock.

=head2 utf8 vs UTF-8

All the C<*_utf8> methods use C<:encoding(UTF-8)> -- either as
C<:unix:encoding(UTF-8)> (unbuffered) or C<:raw:encoding(UTF-8)> (buffered) --
which is strict against the Unicode spec and disallows illegal Unicode
codepoints or UTF-8 sequences.

Unfortunately, C<:encoding(UTF-8)> is very, very slow.  If you install
L<Unicode::UTF8> 0.58 or later, that module will be used by some C<*_utf8>
methods to encode or decode data after a raw, binary input/output operation,
which is much faster.

If you need the performance and can accept the security risk,
C<< slurp({binmode => ":unix:utf8"}) >> will be faster than C<:unix:encoding(UTF-8)>
(but not as fast as C<Unicode::UTF8>).

Note that the C<*_utf8> methods read in B<raw> mode.  There is no CRLF
translation on Windows.  If you must have CRLF translation, use the regular
input/output methods with an appropriate binmode:

  $path->spew_utf8($data);                            # raw
  $path->spew({binmode => ":encoding(UTF-8)"}, $data; # LF -> CRLF

Consider L<PerlIO::utf8_strict> for a faster L<PerlIO> layer alternative to
C<:encoding(UTF-8)>, though it does not appear to be as fast as the
C<Unicode::UTF8> approach.

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

=cut

# vim: ts=4 sts=4 sw=4 et:
