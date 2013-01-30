use 5.008001;
use strict;
use warnings;
use Test::More 0.96;
use File::Spec;
use Path::Tiny;
use Cwd;

my $file1 = path('foo.txt');
isa_ok( $file1, "Path::Tiny" );
is $file1, 'foo.txt';
ok $file1->is_relative;
is $file1->dirname, '.';
is $file1->basename, 'foo.txt';

my $file2 = path('dir', 'bar.txt');
is $file2, 'dir/bar.txt';
ok ! $file2->is_absolute;
is $file2->dirname, 'dir/';
is $file2->basename, 'bar.txt';

my $dir = path('tmp');
is $dir, 'tmp';
ok ! $dir->is_absolute;
is $dir->basename, 'tmp';

my $dir2 = path('/tmp');
is $dir2, '/tmp';
ok $dir2->is_absolute;

my $cat = path($dir, 'foo');
is $cat, 'tmp/foo';
$cat = $dir->child('foo');
is $cat, 'tmp/foo';
is $cat->dirname, 'tmp/';
is $cat->basename, 'foo';

$cat = path($dir2, 'foo');
is $cat, '/tmp/foo';
$cat = $dir2->child('foo');
is $cat, '/tmp/foo';
isa_ok $cat, 'Path::Tiny';
is $cat->dirname, '/tmp/';

$cat = $dir2->child('foo');
is $cat, '/tmp/foo';
isa_ok $cat, 'Path::Tiny';
is $cat->basename, 'foo';

my $file = path('/foo//baz/./foo');
is $file, '/foo/baz/foo';
is $file->dirname, '/foo/baz/';
is $file->parent, '/foo/baz';

{
  my $dir = path('/foo/bar/baz');
  is $dir->parent, '/foo/bar';
  is $dir->parent->parent, '/foo';
  is $dir->parent->parent->parent, '/';
  is $dir->parent->parent->parent->parent, '/';

  $dir = path('foo/bar/baz');
  is $dir->parent, 'foo/bar';
  is $dir->parent->parent, 'foo';
  is $dir->parent->parent->parent, '.';
  is $dir->parent->parent->parent->parent, '..';
  is $dir->parent->parent->parent->parent->parent, '../..';
}

{
  my $dir = path("foo/");
  is $dir, 'foo';
  is $dir->parent, '.';
}

{
  # Special cases
  is path(''), '.';
  is path(), '.';
  is path('', 'var', 'tmp'), 'var/tmp';
  is path()->absolute, path(Cwd::cwd());
  is path(undef), '.';
}

{
  my $file = path('/tmp/foo/bar.txt');
  is $file->relative('/tmp'), 'foo/bar.txt';
  is $file->relative('/tmp/foo'), 'bar.txt';
  is $file->relative('/tmp/'), 'foo/bar.txt';
  is $file->relative('/tmp/foo/'), 'bar.txt';

  $file = path('one/two/three');
  is $file->relative('one'), 'two/three';
}

{
    my $file = Path::Tiny->new(File::Spec->rootdir);
    my $root = Path::Tiny->rootdir;
    is( $file, $root, "rootdir is like path('/')");
}

done_testing();
