my $tmpdir = Path::Tiny->tempdir;
my $dir    = $tmpdir->child("foo");
$dir->mkpath;
$dir = "$dir";

my $result = timethese(
    $count,
    {
        'Path::Tiny'  => sub { path($dir) },
        'Path::Class' => sub { file($dir) },
        'IO::All'     => sub { io($dir) },
        'File::Fu'    => sub { File::Fu->file($dir) },
    },
    "none"
);

