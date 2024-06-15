use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';

use Path::Tiny;


{
    my $renamed1 = path("C:/mydir/myfile.com.extension")->change_extension(".old");
    ok($renamed1->stringify eq 'C:/mydir/myfile.com.old', 'rename to .old with leading perdiod');
    
    my $renamed2 = path("C:/mydir/myfile.com.extension")->change_extension("old");
    ok($renamed2->stringify eq 'C:/mydir/myfile.com.old', 'rename to .old without leading perdiod');
}

{
    my $removed_extension1 = path("C:/mydir/myfile.com.extension")->change_extension(undef);
    ok($removed_extension1->stringify eq 'C:/mydir/myfile.com', 'remove extension');
}

{
    # test for invalid renames of files starting with a period such as .htaccess
    my $died = 0;
    eval {
        path('.htaccess')->change_extension(undef);
    };
    if ($@) {
        $died = 1;
    }
    ok($died, 'Remove extension from file starting with period (and no further etxension) dies as expected');
}

{
    my $dir1 = path("C:/mydir/lookslikedorectory")->change_extension(undef);
    ok($dir1->stringify eq 'C:/mydir/lookslikedorectory', 'directory names without period are kept when removing suffix');
    
    my $dir2 = path("C:/mydir/lookslikedirectory")->change_extension(".exten");
    ok($dir2->stringify eq 'C:/mydir/lookslikedirectory.exten', 'directory names are extended when adding suffix');
    
    my $dir3 = path("C:/mydir/lookslikedirectory")->change_extension("exten");
    ok($dir3->stringify eq 'C:/mydir/lookslikedirectory.exten', 'directory names are extended when adding suffix');
}

done_testing;
