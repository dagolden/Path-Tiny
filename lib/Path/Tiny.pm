use 5.008001;
use strict;
use warnings;

package Path::Tiny;
# ABSTRACT: File path utility
# VERSION

# Dependencies
use autodie::exception 2.14; # autodie::skip support
use Exporter 5.57   (qw/import/);
use File::Spec 3.40 ();
use Carp ();

our @EXPORT    = qw/path/;
our @EXPORT_OK = qw/cwd rootdir tempfile tempdir/;

use constant {
    PATH  => 0,
    CANON => 1,
    VOL   => 2,
    DIR   => 3,
    FILE  => 4,
    TEMP  => 5,
};

use overload (
    q{""}    => sub    { $_[0]->[PATH] },
    bool     => sub () { 1 },
    fallback => 1,
);

my $TID = 0; # for thread safe atomic writes

# if cloning, threads should already be loaded, but Win32 pseudoforks
# don't do that so we have to be sure it's loaded anyway
sub CLONE { require threads; threads->tid }

sub DOES { return $_[1] eq 'autodie::skip' } # report errors like croak

my $HAS_UU;                                  # has Unicode::UTF8; lazily populated

sub _check_UU {
    eval { require Unicode::UTF8; Unicode::UTF8->VERSION(0.58); 1 };
}

# we do our own autodie::exceptions to avoid wrapping built-in functions
sub _throw {
    my ( $function, $args ) = @_;
    die autodie::exception->new(
        function => "CORE::$function",
        args     => $args,
        errno    => $!,
        context  => 'scalar',
        return   => undef,
    );
}

# cheapo option validation
sub _get_args {
    my ( $raw, @valid ) = @_;
    Carp::croak("Options for @{[_called_as()]} must be a hash reference")
      if defined($raw) && ref($raw) ne 'HASH';
    my $cooked = {};
    for my $k (@valid) {
        $cooked->{$k} = delete $raw->{$k} if exists $raw->{$k};
    }
    Carp::croak( "Invalid option(s) for @{[_called_as()]}: " . join( ", ", keys %$raw ) )
      if keys %$raw;
    return $cooked;
}

sub _called_as {
    my ( undef, undef, undef, $method ) = caller(2);
    $method =~ s{^.*::}{};
    return $method;
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

=cut

sub path {
    my $path = shift;
    Carp::croak("path() requires a defined, positive-length argument")
      unless defined $path && length $path;
    # join stringifies any objects, too, which is handy :-)
    $path = join( "/", ( $path eq '/' ? "" : $path ), @_ ) if @_;
    my $cpath = $path = File::Spec->canonpath($path); # ugh, but probably worth it
    $path =~ tr[\\][/];                               # unix convention enforced
    if ( $path =~ m{^(~[^/]*).*} ) {                  # expand a tilde
        my ($homedir) = glob($1); # glob without list context == heisenbug!
        $path =~ s{^(~[^/]*)}{$homedir};
    }
    $path =~ s{/$}{} if $path ne "/"; # hack to make splitpath give us a basename
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

Returns a new C<Path::Tiny> object with an absolute path.  Unless
an argument is given, the current directory is used as the absolute base path.
The argument must be absolute or you won't get an absolute result.

This will not resolve upward directories ("foo/../bar") unless C<canonpath>
in L<File::Spec> would normally do so on your platform.  If you need them
resolved, you must call the more expensive C<realpath> method instead.

=cut

sub absolute {
    my ( $self, $base ) = @_;
    return $self if $self->is_absolute;

    require Cwd;
    return path( join "/", ( defined($base) ? $base : Cwd::getcwd() ), $_[0]->[PATH] );
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
    my $fh = $self->filehandle( ">>", $binmode );

    require Fcntl;
    flock( $fh, Fcntl::LOCK_EX() ) or _throw( 'flock', [ $fh, Fcntl::LOCK_EX() ] );

    # Ensure we're at the end after the lock
    seek( $fh, 0, Fcntl::SEEK_END() ) or _throw( 'seek', [ $fh, 0, Fcntl::SEEK_END() ] );

    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;

    # For immediate flush
    close $fh or _throw( 'close', [$fh] );
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
    my $path = $self->[PATH];
    return path( join( "/", ( $path eq '/' ? "" : $path ), @parts ) );
}

=method children

    @paths = path("/tmp")->children;

Returns a list of C<Path::Tiny> objects for all file and directories
within a directory.  Excludes "." and ".." automatically.

=cut

# XXX take a match parameter?  qr or coderef?
sub children {
    my ($self) = @_;
    my $dh;
    opendir $dh, $self->[PATH] or _throw( 'opendir', [ $dh, $self->[PATH] ] );

    return
      map { path( $self->[PATH] . "/$_" ) } grep { $_ ne '.' && $_ ne '..' } readdir $dh;
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

Returns an open file handle.  The C<$mode> argument must be a Perl-style
read/write mode string ("<" ,">", "<<", etc.).  If a C<$binmode>
is given, it is set during the C<open> call.

See C<openr>, C<openw>, C<openrw>, and C<opena> for sugar.

=cut

# Note: must put binmode on open line, not subsequent binmode() call, so things
# like ":unix" actually stop perlio/crlf from being added

sub filehandle {
    my ( $self, $opentype, $binmode ) = @_;
    $opentype = "<" unless defined $opentype;
    $binmode  = ""  unless defined $binmode;

    my $mode = $opentype . $binmode;
    my $fh;
    open $fh, $mode, $self->[PATH] or _throw( 'open', [ $fh, $mode, $self->[PATH] ] );

    return $fh;
}

=method is_absolute, is_relative

    if ( path("/tmp")->is_absolute ) { ... }
    if ( path("/tmp")->is_relative ) { ... }

Booleans for whether the path appears absolute or relative.

=cut

sub is_absolute { substr( $_[0]->dirname, 0, 1 ) eq '/' }

sub is_relative { substr( $_[0]->dirname, 0, 1 ) ne '/' }

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
                  or _throw( 'opendir', [ $dh, $current->[PATH] ] );
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
    my $fh = $self->filehandle( "<", $binmode );
    require Fcntl;
    flock( $fh, Fcntl::LOCK_SH() ) or _throw( 'flock', [ $fh, Fcntl::LOCK_SH() ] );
    my $chomp = $args->{chomp};
    # XXX more efficient to read @lines then chomp(@lines) vs map?
    if ( $args->{count} ) {
        my (@result, $counter);
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

    return rename( $self->[PATH], $dst ) || _throw( 'rename', [ $self->[PATH], $dst ] );
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

=cut

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
        my ( $self, $binmode ) = @_;
        $binmode = ( ( caller(0) )[10] || {} )->{ 'open' . substr( $v, -1, 1 ) }
          unless defined $binmode;
        $self->filehandle( $v, $binmode );
    };
    *{ $k . "_raw" }  = sub { $_[0]->filehandle( $v, ":raw" ) };
    *{ $k . "_utf8" } = sub { $_[0]->filehandle( $v, ":raw:encoding(UTF-8)" ) };
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
        if ( $self->[FILE] eq '.' || $self->[FILE] =~ /\.\./ ) {
            $parent = path( $self->[PATH] . "/.." );
        }
        else {
            $parent = path( _non_empty( $self->[VOL] . $self->[DIR] ) );
        }
    }
    elsif ( length $self->[DIR] ) {
        if ( $self->[DIR] =~ /\.\./ ) {
            $parent = path( $self->[VOL] . $self->[DIR] . "/.." );
        }
        else {
            $parent = path("/") if $self->[DIR] eq "/";
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

=cut

sub realpath {
    require Cwd;
    return path( Cwd::realpath( $_[0]->[PATH] ) );
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

    return unlink $self->[PATH] || _throw( 'unlink', [ $self->[PATH] ] );
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
    my $fh = $self->filehandle( "<", $binmode );
    require Fcntl;
    flock( $fh, Fcntl::LOCK_SH() ) or _throw( 'flock', [ $fh, Fcntl::LOCK_SH() ] );
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
    $binmode = ( ( caller(0) )[10] || {} )->{'open>'} unless defined $binmode;
    my $temp = path( $self->[PATH] . $TID . $$ );
    my $fh = $temp->filehandle( ">", $binmode );
    require Fcntl;
    flock( $fh, Fcntl::LOCK_EX() ) or _throw( 'flock', [ $fh, Fcntl::LOCK_EX() ] );
    seek( $fh, 0, Fcntl::SEEK_SET() ) or _throw( 'seek', [ $fh, 0, Fcntl::SEEK_SET() ] );
    truncate( $fh, 0 ) or _throw( 'truncate', [ $fh, 0 ] );
    print {$fh} map { ref eq 'ARRAY' ? @$_ : $_ } @data;
    flock( $fh, Fcntl::LOCK_UN() ) or _throw( 'flock', [ $fh, Fcntl::LOCK_UN() ] );
    close $fh or _throw( 'close', [$fh] );

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
    return File::stat::stat( $self->[PATH] ) || _throw( 'stat', [ $self->[PATH] ] );
}

sub lstat {
    my $self = shift;
    require File::stat;
    return File::stat::lstat( $self->[PATH] ) || _throw( 'lstat', [ $self->[PATH] ] );
}

=method stringify

    $path = path("foo.txt");
    say $path->stringify; # same as "$path"

Returns a string representation of the path.  Unlike C<canonpath>, this method
returns the path standardized with Unix-style C</> directory separators.

=cut

sub stringify { $_[0]->[PATH] }

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
        close $fh or _throw( 'close', [$fh] );
    }
    $epoch = defined($epoch) ? $epoch : time();
    utime $epoch, $epoch, $self->[PATH]
      or _throw( 'utime', [ $epoch, $epoch, $self->[PATH] ] );
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

    $vol = path("/tmp/foo.txt")->volume;

Returns the volume portion of the path.  This is equivalent
equivalent to what L<File::Spec> would give from C<splitpath> and thus
usually is the empty string on Unix-like operating systems.

=cut

sub volume {
    my ($self) = @_;
    $self->_splitpath unless defined $self->[VOL];
    return $self->[VOL];
}

1;

=for Pod::Coverage
openr_utf8 opena_utf8 openw_utf8 openrw_utf8
openr_raw opena_raw openw_raw openrw_raw
DOES

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
as appropriate.

The C<*_utf8> methods (C<slurp_utf8>, C<lines_utf8>, etc.) operate in raw
mode without CRLF translation.  Installing L<Unicode::UTF8> 0.58 or later
will speed up several of them and is highly recommended.

It uses L<autodie> internally, so most failures will be thrown as exceptions.

=head1 CAVEATS

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
etc.) and high-level handle opening methods ( C<openr>, C<openw>, etc. but not
C<filehandle>) respect default encodings set by the C<-C> switch or lexical
L<open> settings of the caller.  For UTF-8, this is almost certainly slower
than using the dedicated C<_utf8> methods if you have L<Unicode::UTF8>.

=head1 TYPE CONSTRAINTS AND COERCION

A standard L<MooseX::Types> library is available at
L<MooseX::Types::Path::Tiny>.

=head1 SEE ALSO

These are other file/path utilities, which may offer a different feature
set than C<Path::Tiny>.

* L<File::Fu>
* L<IO::All>
* L<Path::Class>

These iterators may be slightly faster than the recursive iterator in
C<Path::Tiny>:

* L<Path::Iterator::Rule>
* L<File::Next>

There are probably comparable, non-Tiny tools.  Let me know if you want me to
add a module to the list.

=cut

# vim: ts=4 sts=4 sw=4 et:
