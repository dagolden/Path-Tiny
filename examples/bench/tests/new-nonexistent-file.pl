my $result = timethese(
    $count,
    {
        'Path::Tiny'  => sub { path("$ENV{HOME}/foo.txt") },
        'Path::Class' => sub { file("$ENV{HOME}/foo.txt") },
        'IO::All'     => sub { io("$ENV{HOME}/foo.txt") },
        'File::Fu'    => sub { File::Fu->file("$ENV{HOME}/foo.txt") },
    },
    "none"
);

