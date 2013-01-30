use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Temp qw(tmpnam tempdir);
use File::Spec;

use Path::Tiny;

my $file = path( scalar tmpnam() );
ok $file, "Got a filename via tmpnam()";

{
    my $fh = $file->openw;
    ok $fh, "Opened $file for writing";

    ok print( $fh "Foo\n" ), "Printed to $file";
}

ok -e $file, "$file should exist";

{
    my $fh = $file->openr;
    is scalar <$fh>, "Foo\n", "Read contents of $file correctly";
}

{
    my $stat = $file->stat;
    ok $stat;
    cmp_ok $stat->mtime, '>', time() - 20; # Modified within last 20 seconds

    $stat = $file->parent->stat;
    ok $stat;
}

1 while unlink $file;
ok not -e $file;

my $dir = path( tempdir( CLEANUP => 1 ) );
ok $dir;
ok -d $dir;

$file = $dir->child('foo.x');
$file->touch;
ok -e $file;

{
    my @files = $dir->children;
    is scalar @files, 1 or diag explain \@files;
    ok scalar grep { /foo\.x/ } @files;
}

ok $dir->remove, "Removed $dir";
ok !-e $dir, "$dir no longer exists";

{
    $dir = path( 't', 'foo', 'bar' );
    $dir->parent->remove if -e $dir->parent;

    ok $dir->mkpath, "Created $dir";
    ok -d $dir, "$dir is a directory";

    $dir = $dir->parent;
    ok $dir->remove;
    ok !-e $dir;
}

{
    $dir = path( 't', 'foo' );
    ok $dir->mkpath;
    ok $dir->child('dir')->mkpath;
    ok -d $dir->child('dir');

    ok $dir->child('file.x')->touch;
    ok $dir->child('0')->touch;
    my @contents;
    my $iter = $dir->iterator;
    while ( defined( my $file = $iter->() ) ) {
        push @contents, $file;
    }
    is scalar @contents, 3
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

    ok $dir->remove;
    ok !-e $dir;

    # Try again with directory called '0', in curdir
    my $orig = path()->absolute;

    ok $dir->mkpath;
    ok chdir($dir);
    my $dir2 = path();
    ok $dir2->child('0')->mkpath;
    ok -d $dir2->child('0');

    @contents = ();
    $iter     = $dir2->iterator;
    while ( my $file = $iter->() ) {
        push @contents, $file;
    }
    ok grep { $_ eq '0' } @contents;

    ok chdir($orig);
    ok $dir->remove;
    ok !-e $dir;
}

{
    my $file = path( 't', 'slurp' );
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

    $file->remove;
    ok not -e $file;
}

{
    my $file = path( 't', 'slurp' );
    ok $file;

    my $fh = $file->openw(':raw') or die "Can't create $file: $!";
    print $fh "Line1\r\nLine2\r\n\302\261\r\n";
    close $fh;
    ok -e $file;

    my $content = $file->slurp( { binmode => ':raw' } );
    is $content, "Line1\r\nLine2\r\n\302\261\r\n";

    my $line3 = "\302\261\n";
    utf8::decode($line3);
    my @content = $file->lines( { binmode => ':crlf:utf8' } );
    is_deeply \@content, [ "Line1\n", "Line2\n", $line3 ];

    chop($line3);
    @content = $file->lines( {chomp => 1, binmode => ':crlf:utf8'} );
    is_deeply \@content, [ "Line1", "Line2", $line3 ];

    $file->remove;
    ok not -e $file;
}

##{
##    my $file = path( 't', 'spew');
##    $file->remove() if -e $file;
##    $file->spew( iomode => '>:raw', "Line1\r\n" );
##    $file->spew( iomode => '>>', "Line2" );
##
##    my $content = $file->slurp( iomode => '<:raw');
##
##    is( $content, "Line1\r\nLine2" );
##}

{
    # Make sure we can make an absolute/relative roundtrip
    my $cwd = path();
    is $cwd, $cwd->absolute->relative,
      "from $cwd to " . $cwd->absolute . " to " . $cwd->absolute->relative;
}

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

##{
##  # Test recursive iteration through the following structure:
##  #     a
##  #    / \
##  #   b   c
##  #  / \   \
##  # d   e   f
##  #    / \   \
##  #   g   h   i
##  (my $abe = path( qw(a b e)))->mkpath;
##  (my $acf = path( qw(a c f)))->mkpath;
##  path( $acf, 'i')->touch;
##  path( $abe, 'h')->touch;
##  path( $abe, 'g')->touch;
##  path( 'a', 'b', 'd')->touch;
##
##  my $a = path( 'a');
##
##  # Make sure the children() method works ok
##  my @children = sort map $_->as_foreign('Unix'), $a->children;
##  is_deeply \@children, ['a/b', 'a/c'];
##
##  {
##    recurse_test( $a,
##		  preorder => 1, depthfirst => 0,  # The default
##		  precedence => [qw(a           a/b
##				    a           a/c
##				    a/b         a/b/e/h
##				    a/b         a/c/f/i
##				    a/c         a/b/e/h
##				    a/c         a/c/f/i
##				   )],
##		);
##  }
##
##  {
##    my $files =
##      recurse_test( $a,
##		    preorder => 1, depthfirst => 1,
##		    precedence => [qw(a           a/b
##				      a           a/c
##				      a/b         a/b/e/h
##				      a/c         a/c/f/i
##				     )],
##		  );
##    is_depthfirst($files);
##  }
##
##  {
##    my $files =
##      recurse_test( $a,
##		    preorder => 0, depthfirst => 1,
##		    precedence => [qw(a/b         a
##				      a/c         a
##				      a/b/e/h     a/b
##				      a/c/f/i     a/c
##				     )],
##		  );
##    is_depthfirst($files);
##  }
##
##
##  $a->remove;
##
##  sub is_depthfirst {
##    my $files = shift;
##    if ($files->{'a/b'} < $files->{'a/c'}) {
##      cmp_ok $files->{'a/b/e'}, '<', $files->{'a/c'}, "Ensure depth-first search";
##    } else {
##      cmp_ok $files->{'a/c/f'}, '<', $files->{'a/b'}, "Ensure depth-first search";
##    }
##  }
##
##  sub recurse_test {
##    my ($dir, %args) = @_;
##    my $precedence = delete $args{precedence};
##    my ($i, %files) = (0);
##    $a->recurse( callback => sub {$files{shift->as_foreign('Unix')->stringify} = ++$i},
##		 %args );
##    while (my ($pre, $post) = splice @$precedence, 0, 2) {
##      cmp_ok $files{$pre}, '<', $files{$post}, "$pre should come before $post";
##    }
##    return \%files;
##  }
##}

{
    $dir = Path::Tiny->tempdir();
    isa_ok $dir, 'Path::Tiny';
};

done_testing;
