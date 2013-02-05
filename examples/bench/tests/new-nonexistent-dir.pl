my $result = timethese(
    $count,
    {
        'Path::Tiny'  => sub { path("$ENV{HOME}/foo") },
        'Path::Class' => sub { dir("$ENV{HOME}/foo") },
        'IO::All'     => sub { io("$ENV{HOME}/foo") },
        'File::Fu'    => sub { File::Fu->dir("$ENV{HOME}/foo") },
    },
    "none"
);

