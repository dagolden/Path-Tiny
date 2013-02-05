my $file = "$ENV{HOME}/git/perl/AUTHORS";

my $result = timethese (
    $count,
    {
        'Path::Tiny'  => sub { my $s = path($file)->slurp_utf8 },
        'Path::Class' => sub { my $s = file($file)->slurp(iomode => "<:encoding(UTF-8)") },
        'IO::All'     => sub { my $s = io($file)->binmode(":encoding(UTF-8)")->slurp },
        'File::Fu'    => sub { my $s = File::Fu->file($file)->read({binmode => ":encoding(UTF-8)"}) },
    },
    "none"
);

