use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';
use TestUtils qw/exception/;

use Config;
use Path::Tiny;
use Cwd 'abs_path';

{
    my $newtmp = Path::Tiny->tempdir;
    my $file   = $newtmp->child("foo.txt");
    my $link   = $newtmp->child("bar.txt");
    $file->spew("Hello World\n");
    eval { symlink $file => $link; die unless -l $link };
}

plan skip_all => "No symlink support" if $@;

subtest "relative symlinks with updir" => sub {
    my $temp = Path::Tiny->tempdir;
    my $td   = $temp->realpath;
    $td->child(qw/tmp tmp2/)->mkpath;

    my $foo = $td->child(qw/tmp foo/)->touch;
    my $bar = $td->child(qw/tmp tmp2 bar/);

    symlink "../foo", $bar or die "Failed to symlink: $!\n";

    ok -f $foo, "it's a file";
    ok -l $bar, "it's a link";

    is readlink $bar, "../foo", "the link seems right";
    is abs_path($bar), $foo, "abs_path gets's it right";

    is $bar->realpath, $foo, "realpath get's it right";
};

subtest "symlink loop detection" => sub {
    my $temp = Path::Tiny->tempdir;
    my $td   = $temp->realpath;
    $td->child("A")->touch;
    for my $pair ( [qw/A B/], [qw/B C/], [qw/C A/] ) {
        my $target = $td->child( $pair->[1] );
        $target->remove if -e $target;
        symlink $pair->[0], $td->child( $pair->[1] ) or die "Failed to symlink @$pair: $!\n";
    }
    diag for $td->children;
    like(
        exception { $td->child("A")->realpath },
        qr/symlink loop detected/,
        "symlink loop detected"
    );
};

done_testing;

# COPYRIGHT
# vim: set ts=4 sts=4 sw=4 et tw=75:
