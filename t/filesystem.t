use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Temp qw(tmpnam tempdir);
use File::Spec;
use Config;
use Cwd;

use lib 't/lib';
use TestUtils qw/exception/;

use Path::Tiny;

# Tests adapted from Path::Class t/basic.t

my $file = path( scalar tmpnam() );
ok $file, "Got a filename via tmpnam()";

{
    my $fh = $file->openw;
    ok $fh, "Opened $file for writing";

    ok print( $fh "Foo\n" ), "Printed to $file";
}

ok -e $file, "$file should exist";
ok $file->is_file, "it's a file!";

if ( -e "/dev/null" ) {
    ok( path("/dev/null")->is_file, "/dev/null is_file, too" );
}

my ( $volume, $dirname, $basename ) =
  map { s{\\}{/}; $_ } File::Spec->splitpath($file);
is( $file->volume,   $volume,   "volume correct" );
is( $file->volume,   $volume,   "volume cached " );  # for coverage
is( $file->dirname,  $dirname,  "dirname correct" );
is( $file->basename, $basename, "basename correct" );

{
    my $fh = $file->openr;
    is scalar <$fh>, "Foo\n", "Read contents of $file correctly";
}

note "stat";
{
    my $stat = $file->stat;
    ok $stat;
    cmp_ok $stat->mtime, '>', time() - 20; # Modified within last 20 seconds

    $stat = $file->parent->stat;
    ok $stat;
}

note "stat/lstat with no file";
{
    my $file = "i/do/not/exist";
    ok exception { path($file)->stat };
    ok exception { path($file)->lstat };
}

1 while unlink $file;
ok not -e $file;

my $dir = path( tempdir( TMPDIR => 1, CLEANUP => 1 ) );
ok $dir;
ok -d $dir;
ok $dir->is_dir, "It's a directory!";

$file = $dir->child('foo.x');
$file->touch;
ok -e $file;
my $epoch = time - 10;
utime $epoch, $epoch, $file;
$file->touch;
ok( $file->stat->mtime > $epoch, "touch sets utime as current time" );
$file->touch($epoch);
ok( $file->stat->mtime == $epoch, "touch sets utime as 10 secs before" );

{
    my @files = $dir->children;
    is scalar @files, 1 or diag explain \@files;
    ok scalar grep { /foo\.x/ } @files;
}

ok $dir->remove_tree, "Removed $dir";
ok !-e $dir, "$dir no longer exists";
ok !$dir->remove_tree, "Removing non-existent dir returns false";

my $tmpdir = Path::Tiny->tempdir;

{
    $dir = path( $tmpdir, 'foo', 'bar' );
    $dir->parent->remove_tree if -e $dir->parent;

    ok $dir->mkpath, "Created $dir";
    ok -d $dir, "$dir is a directory";

    $dir = $dir->parent;
    ok $dir->remove_tree( { safe => 1 } ); # check that we pass through args
    ok !-e $dir;
}

{
    $dir = path( $tmpdir, 'foo' );
    ok $dir->mkpath;
    ok $dir->child('dir')->mkpath;
    ok -d $dir->child('dir');

    ok $dir->child('file.x')->touch;
    ok $dir->child('0')->touch;
    ok $dir->child('foo/bar/baz.txt')->touchpath;

    subtest 'iterator' => sub {
        my @contents;
        my $iter = $dir->iterator;
        while ( my $file = $iter->() ) {
            push @contents, $file;
        }
        is scalar @contents, 4
          or diag explain \@contents;
        is( $iter->(), undef, "exhausted iterator is undef" );

        my $joined = join ' ', sort map $_->basename, grep { -f $_ } @contents;
        is $joined, '0 file.x'
          or diag explain \@contents;

        my ($subdir) = grep { $_ eq $dir->child('dir') } @contents;
        ok $subdir;
        is -d $subdir, 1;

        my ($file) = grep { $_ eq $dir->child('file.x') } @contents;
        ok $file;
        is -d $file, '';
    };

    subtest 'visit' => sub {
        my @contents;
        $dir->visit( sub { push @contents, $_[0] } );
        is scalar @contents, 4
          or diag explain \@contents;

        my $joined = join ' ', sort map $_->basename, grep { -f $_ } @contents;
        is $joined, '0 file.x'
          or diag explain \@contents;

        my ($subdir) = grep { $_ eq $dir->child('dir') } @contents;
        ok $subdir;
        is -d $subdir, 1;

        my ($file) = grep { $_ eq $dir->child('file.x') } @contents;
        ok $file;
        is -d $file, '';
    };

    ok $dir->remove_tree;
    ok !-e $dir;

    # Try again with directory called '0', in curdir
    my $orig = Path::Tiny->cwd;

    ok $dir->mkpath;
    ok chdir($dir);
    my $dir2 = path(".");
    ok $dir2->child('0')->mkpath;
    ok -d $dir2->child('0');

    subtest 'iterator' => sub {
        my @contents;
        my $iter = $dir2->iterator;
        while ( my $file = $iter->() ) {
            push @contents, $file;
        }
        ok grep { $_ eq '0' } @contents;
    };
    subtest 'visit' => sub {
        my @contents;
        $dir2->visit( sub { push @contents, $_[0] } );
        ok grep { $_ eq '0' } @contents;
    };

    ok chdir($orig);
    ok $dir->remove_tree;
    ok !-e $dir;
}

{
    my $file = path( $tmpdir, 'slurp' );
    ok $file;

    my $fh = $file->openw or die "Can't create $file: $!";
    print $fh "Line1\nLine2\n";
    close $fh;
    ok -e $file;

    my $content = $file->slurp;
    is $content, "Line1\nLine2\n";

    my @content = $file->lines;
    is_deeply \@content, [ "Line1\n", "Line2\n" ];

    @content = $file->lines( { chomp => 1 } );
    is_deeply \@content, [ "Line1", "Line2" ];

    ok( $file->remove, "removing file" );
    ok !-e $file, "file is gone";
    ok !$file->remove, "removing file again returns false";

    my $subdir = $tmpdir->child('subdir');
    ok $subdir->mkpath;
    ok exception { $subdir->remove }, "calling 'remove' on a directory throws";
    ok rmdir $subdir;

    my $orig = Path::Tiny->cwd;
    ok chdir $tmpdir;
    my $zero_file = path '0';
    ok $zero_file->openw;
    ok $zero_file->remove, "removing file called '0'";
    ok chdir $orig;
}

{
    my $file = path( $tmpdir, 'slurp' );
    ok $file;

    my $fh = $file->openw(':raw') or die "Can't create $file: $!";
    print $fh "Line1\r\nLine2\r\n\302\261\r\n";
    close $fh;
    ok -e $file;

    my $content = $file->slurp( { binmode => ':raw' } );
    is $content, "Line1\r\nLine2\r\n\302\261\r\n", "slurp raw";

    my $line3 = "\302\261\n";
    utf8::decode($line3);

    $content = $file->slurp( { binmode => ':crlf:utf8' } );
    is $content, "Line1\nLine2\n" . $line3, "slurp+crlf+utf8";

    my @content = $file->lines( { binmode => ':crlf:utf8' } );
    is_deeply \@content, [ "Line1\n", "Line2\n", $line3 ], "lines+crlf+utf8";

    chop($line3);
    @content = $file->lines( { chomp => 1, binmode => ':crlf:utf8' } );
    is_deeply \@content, [ "Line1", "Line2", $line3 ], "lines+chomp+crlf+utf8";

    $file->remove;
    ok not -e $file;
}

{
    my $file = path( $tmpdir, 'spew' );
    $file->remove() if $file->exists;
    $file->spew( { binmode => ':raw' }, "Line1\r\n" );
    $file->append( { binmode => ':raw' }, "Line2" );

    my $content = $file->slurp( { binmode => ':raw' } );

    is( $content, "Line1\r\nLine2" );
}

{
    # Make sure we can make an absolute/relative roundtrip
    my $cwd = path(".");
    is $cwd, $cwd->absolute->relative,
      "from $cwd to " . $cwd->absolute . " to " . $cwd->absolute->relative;
}

{
    # realpath should resolve ..
    my $lib  = path("t/../lib");
    my $real = $lib->realpath;
    unlike $real, qr/\.\./, "updir gone from realpath";
    my $abs_lib = $lib->absolute;
    my $abs_t   = path("t")->absolute;
    my $case    = $abs_t->child("../lib");
    is( $case->realpath, $lib->realpath, "realpath on absolute" );

    # non-existent directory in realpath should throw error
    eval { path("lkajdfak/djslakdj")->realpath };
    like(
        $@,
        qr/Error resolving realpath/,
        "caught error from realpath on non-existent dir"
    );

    # but non-existent basename in realpath should throw error
    eval { path("./djslakdj")->realpath };
    is( $@, '', "no error from realpath on non-existent last component" );
}

subtest "copy()" => sub {
    my $file = $tmpdir->child("foo.txt");
    $file->spew("Hello World\n");

    my $copy;
    subtest "dest is a file" => sub {
        $copy = $tmpdir->child("bar.txt");
        my $result = $file->copy($copy);
        is "$result" => "$copy", "returned the right file";

        is( $copy->slurp, "Hello World\n", "file copied" );
    };

    subtest "dest is a dir" => sub {
        # new tempdir nto to clobber the original foo.txt
        my $tmpdir = Path::Tiny->tempdir;
        my $result = $file->copy($tmpdir);

        is "$result" => "$tmpdir/foo.txt", "returned the right file";

        is $result->slurp, "Hello World\n", "file copied";
    };

    subtest "try some different chmods" => sub {
        ok( $copy->chmod(0000),   "chmod(0000)" );
        ok( $copy->chmod("0400"), "chmod('0400')" );
        SKIP: {
            skip "No exception if run as root", 1 if $> == 0;
            skip "No exception writing to read-only file", 1
              unless
              exception { open my $fh, ">", "$copy" or die }; # probe if actually read-only
            my $error = exception { $file->copy($copy) };
            ok( $error, "copy throws error if permission denied" );
            like( $error, qr/\Q$file/, "error messages includes the source file name" );
            like( $error, qr/\Q$copy/, "error messages includes the destination file name" );
        }
        ok( $copy->chmod("u+w"), "chmod('u+w')" );
    };
};

{
    $tmpdir->child( "subdir", "touched.txt" )->touchpath->spew("Hello World\n");
    is(
        $tmpdir->child( "subdir", "touched.txt" )->slurp,
        "Hello World\n",
        "touch can chain"
    );
}

SKIP: {
    my $newtmp = Path::Tiny->tempdir;
    my $file   = $newtmp->child("foo.txt");
    my $link   = $newtmp->child("bar.txt");
    $file->spew("Hello World\n");
    eval { symlink $file => $link };
    skip "symlink unavailable", 1 unless $Config{d_symlink};
    ok( $link->lstat->size, "lstat" );

    is( $link->realpath, $file->realpath, "realpath resolves symlinks" );

    ok $link->remove, 'remove symbolic link';
    ok $file->remove;

    $file = $newtmp->child("foo.txt");
    $link = $newtmp->child("bar.txt");
    $file->spew("Hello World\n");
    ok symlink $file => $link;

    ok $file->remove;
    ok $link->remove, 'remove broken symbolic link';

    my $dir = $newtmp->child('foo');
    $link = $newtmp->child("bar");
    ok $dir->mkpath;
    ok -d $dir;
    $file = $dir->child("baz.txt");
    $file->spew("Hello World\n");
    ok symlink $dir => $link;

    ok $link->remove_tree, 'remove_tree symbolic link';
    ok $dir->remove_tree;

    $dir  = $newtmp->child('foo');
    $link = $newtmp->child("bar");
    ok $dir->mkpath;
    ok -d $dir;
    $file = $dir->child("baz.txt");
    $file->spew("Hello World\n");
    ok symlink $dir => $link;

    ok $dir->remove_tree;
    ok $link->remove_tree, 'remove_tree broken symbolic link';

    $file = $newtmp->child("foo.txt");
    $link = $newtmp->child("bar.txt");
    my $link2 = $newtmp->child("baz.txt");
    $file->spew("Hello World\n");
    ok symlink $file => $link;
    ok symlink $link => $link2;
    $link2->spew("Hello Perl\n");
    ok -l $link2, 'path is still symbolic link after spewing';
    is readlink($link2), $link, 'symbolic link is available after spewing';
    is readlink($link),  $file, 'symbolic link is available after spewing';
    is $file->slurp, "Hello Perl\n",
      'spewing follows the link and replace the destination instead';
}

# We don't have subsume so comment these out.  Keep in case we
# implement it later

##{
##  my $t = path( 't');
##  my $foo_bar = $t->child('foo','bar');
##  $foo_bar->remove; # Make sure it doesn't exist
##
##  ok  $t->subsumes($foo_bar), "t subsumes t/foo/bar";
##  ok !$t->contains($foo_bar), "t doesn't contain t/foo/bar";
##
##  $foo_bar->mkpath;
##  ok  $t->subsumes($foo_bar), "t still subsumes t/foo/bar";
##  ok  $t->contains($foo_bar), "t now contains t/foo/bar";
##
##  $t->child('foo')->remove;
##}

done_testing;
