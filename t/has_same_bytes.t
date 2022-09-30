use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception has_symlinks/;

use Path::Tiny;

my $dir  = Path::Tiny->tempdir;

# identical contents in two files
my $file1a = $dir->child("file1b.txt");
my $file1b = $dir->child("file1a.txt");
for my $f ( $file1a, $file1b ) {
    $f->spew("hello world");
}

# different contents
my $file2 = $dir->child("file2.txt");
$file2->spew("goodbye world");

# a directory, instead of a file
my $subdir = $dir->child("subdir");
$subdir->mkpath;

subtest "only files" => sub  {
    ok( $file1a->has_same_bytes($file1a), "same file");
    ok( $file1a->has_same_bytes($file1b), "different files, same contents");
    ok( ! $file1a->has_same_bytes($file2), "different files, different contents");
};

subtest "symlinks" => sub  {
    plan skip_all => "No symlink support"
      unless has_symlinks();

    my $file1c = $dir->child("file1c.txt");
    symlink "$file1a" => "$file1c";

    ok( $file1a->has_same_bytes($file1c), "file compared to self symlink");
    ok( $file1c->has_same_bytes($file1a), "self symlink compared to file");
};

subtest "exception" => sub  {
    my $doesnt_exist = $dir->child("doesnt_exist.txt");

    like( exception { $file1a->has_same_bytes($doesnt_exist) }, qr/no such file/i, "file->has_same_bytes(doesnt_exist)");
    like( exception { $doesnt_exist->has_same_bytes($file1a) }, qr/no such file/i, "doesnt_exist->has_same_bytes(file)");
    like( exception { $file1a->has_same_bytes($subdir) }, qr/directory not allowed/, "file->has_same_bytes(dir)");
    like( exception { $subdir->has_same_bytes($file1a) }, qr/directory not allowed/, "dir->has_same_bytes(file)");
    like( exception { $subdir->has_same_bytes($subdir) }, qr/directory not allowed/, "dir->has_same_bytes(dir)");
    like( exception { $subdir->has_same_bytes($dir) }, qr/directory not allowed/, "dir->has_same_bytes(different_dir)");
};


done_testing;
# COPYRIGHT
