my $tmpdir = Path::Tiny->tempdir;
my $file   = $tmpdir->child("foo.txt");
$file->touch;
$file = "$file";

my $result = timethese(
    $count,
    {
        'Path::Tiny'  => sub { path($file) },
        'Path::Class' => sub { file($file) },
        'IO::All'     => sub { io($file) },
        'File::Fu'    => sub { File::Fu->file($file) },
    },
    "none",
);

