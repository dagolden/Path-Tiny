my $file = "fooabc123.txt";

my $result = timethese(
    $count,
    {
        'Path::Tiny'  => sub { path($file)->absolute },
        'Path::Class' => sub { file($file)->absolute },
        'IO::All'     => sub { io($file)->absolute },
        'File::Fu'    => sub { File::Fu->file($file)->absolute },
    },
    "none"
);

