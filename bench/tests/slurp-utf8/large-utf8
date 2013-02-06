my $file = "$ENV{HOME}/tmp/BIGAUTHORS";

my $result = timethese(
    $count,
    {
        'Path::Tiny' => sub { my $s = path($file)->slurp( { binmode => ":utf8" } ) },
        'Path::Class' => sub { my $s = file($file)->slurp( iomode => "<:utf8" ) },
        'IO::All' => sub { my $s = io($file)->utf8->slurp },
        'File::Fu' => sub { my $s = File::Fu->file($file)->read( { binmode => ":utf8" } ) },
    },
    "none"
);

