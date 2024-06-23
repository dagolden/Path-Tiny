use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use lib 't/lib';

use Path::Tiny;

my @cases = (
    # path1 => path2 => path1->subsumes(path2)

    "rename path with extension" => [
        [ '.',                            '.ext',     '.ext'                        ],
        [ '/',                            '.ext',     '/.ext'                       ],
        [ '..',                           '.ext',     '..ext'                       ],
        [ '../..',                        '.ext',     '../..ext'                    ],
        [ '/foo/',                        '.ext',     '/foo.ext'                    ], # differs from C#: /foo/.ext
        [ '/foo',                         '.ext',     '/foo.ext'                    ],
        [ 'foo/',                         '.ext',     'foo.ext'                     ], # differs from C#: foo/.ext
        [ './foo',                        '.ext',     'foo.ext'                     ], # differs from C#: ./foo.ext
        [ 'foo/.',                        '.ext',     'foo.ext'                     ], # differs from C#: foo/.ext
        [ 'C:/temp/myfile.com.extension', '.old',     'C:/temp/myfile.com.old'      ],
        [ 'C:/temp/myfile.com.extension', 'old',      'C:/temp/myfile.com.old'      ],
        [ 'C:/pathwithoutextension',      '.old',     'C:/pathwithoutextension.old' ],
        [ 'C:/pathwithoutextension',      'old',      'C:/pathwithoutextension.old' ],
        # ~ paths
    ],

    "remove extension" => [
        [ '.',                            undef,     ''                        ],
        [ '/',                            undef,     '/'                       ],
        [ '..',                           undef,     '.'                       ],
        [ '../..',                        undef,     '../.'                    ],
        [ '/foo/',                        undef,     '/foo'                    ], # differs from C#: /foo/
        [ '/foo',                         undef,     '/foo'                    ],
        [ 'foo/',                         undef,     'foo'                     ], # differs from C#: foo/
        [ './foo',                        undef,     'foo'                     ], # differs from C#: ./foo
        [ 'foo/.',                        undef,     'foo'                     ], # differs from C#: foo/
        [ 'C:/temp/myfile.com.extension', undef,     'C:/temp/myfile.com'      ],
        [ 'C:/temp/myfile.com.extension', undef,     'C:/temp/myfile.com'      ],
        [ 'C:/pathwithoutextension',      undef,     'C:/pathwithoutextension' ],
        [ 'C:/pathwithoutextension',      undef,     'C:/pathwithoutextension' ],
    ],

);



while (@cases) {
    my ( $subtest, $tests ) = splice( @cases, 0, 2 );
    
    subtest $subtest => sub {
        for my $t (@$tests) {
            my ( $path1, $ext, $path2 ) = @$t;
            my $label = sprintf("%s + %s -> %s", $path1, (defined $ext ? $ext : 'undef'), $path2);
            my $changed_path = path($path1)->change_extension($ext);
            ok( $changed_path->stringify eq $path2, $label )
              or diag "PATH 1:\n", explain( path($path1) ), "\nCHANGED PATH:\n", explain( $changed_path ), "\nPATH2:\n",
              explain( path($path2) );
        }
    };
}

ok(1);

done_testing;
