use 5.008001;
use strict;
use warnings;
use Test::More 0.96;

use Path::Tiny;

# tests adapted from File::Spec's t/Spec.t test

# Each element in this array is a single test. Storing them this way makes
# maintenance easy, and should be OK since perl should be pretty functional
# before these tests are run.

my @tests = (
# [ Function          ,            Expected          ,         Platform ]

[ "path('a','b','c')",         'a/b/c'  ],
[ "path('a','b','./c')",       'a/b/c'  ],
[ "path('./a','b','c')",       'a/b/c'  ],
[ "path('c')",                 'c' ],
[ "path('./c')",               'c' ],

[ "path()",                     '.'          ],
[ "path('')",                   '.'         ],
[ "path('/')",                  '/'         ],
[ "path('','d1','d2','d3','')", '/d1/d2/d3' ],
[ "path('d1','d2','d3','')",    'd1/d2/d3'  ],
[ "path('','d1','d2','d3')",    '/d1/d2/d3' ],
[ "path('d1','d2','d3')",       'd1/d2/d3'  ],
[ "path('/','d2/d3')",          '/d2/d3'    ],

[ "path('///../../..//./././a//b/.././c/././')",   '/a/b/../c' ],
[ "path('a/../../b/c')",            'a/../../b/c'    ],
[ "path('/.')",                     '/'              ],
[ "path('/./')",                    '/'              ],
[ "path('/a/./')",                  '/a'             ],
[ "path('/a/.')",                   '/a'             ],
[ "path('/../../')",                '/'              ],
[ "path('/../..')",                 '/'              ],

[  "path('/t1/t2/t3')->relative('/t1/t2/t3')",          '.'                  ],
[  "path('/t1/t2/t4')->relative('/t1/t2/t3')",          '../t4'              ],
[  "path('/t1/t2')->relative('/t1/t2/t3')",             '..'                 ],
[  "path('/t1/t2/t3/t4')->relative('/t1/t2/t3')",       't4'                 ],
[  "path('/t4/t5/t6')->relative('/t1/t2/t3')",          '../../../t4/t5/t6'  ],
[  "path('/')->relative('/t1/t2/t3')",                  '../../..'           ],
[  "path('///')->relative('/t1/t2/t3')",                '../../..'           ],
[  "path('/.')->relative('/t1/t2/t3')",                 '../../..'           ],
[  "path('/./')->relative('/t1/t2/t3')",                '../../..'           ],
[  "path('/t1/t2/t3')->relative( '/')",                 't1/t2/t3'           ],
[  "path('/t1/t2/t3')->relative( '/t1')",               't2/t3'              ],
[  "path('t1/t2/t3')->relative( 't1')",                 't2/t3'              ],
[  "path('t1/t2/t3')->relative( 't4')",                 '../t1/t2/t3'        ],
[  "path('.')->relative( '.')",                         '.'                  ],
[  "path('/')->relative( '/')",                         '.'                  ],
[  "path('../t1')->relative( 't2/t3')",                 '../../../t1'        ],
[  "path('t1')->relative( 't2/../t3')",                 '../t1'              ],


[ "path('t4')->absolute('/t1/t2/t3')",             '/t1/t2/t3/t4'    ],
[ "path('t4/t5')->absolute('/t1/t2/t3')",          '/t1/t2/t3/t4/t5' ],
[ "path('.')->absolute('/t1/t2/t3')",              '/t1/t2/t3'       ],
[ "path('..')->absolute('/t1/t2/t3')",             '/t1/t2/t3/..'    ],
[ "path('../t4')->absolute('/t1/t2/t3')",          '/t1/t2/t3/../t4' ],
[ "path('/t1')->absolute('/t1/t2/t3')",            '/t1'             ],

##[ "Win32->catdir()",                        ''                   ],
##[ "Win32->catdir('')",                      '\\'                 ],
##[ "Win32->catdir('/')",                     '\\'                 ],
##[ "Win32->catdir('/', '../')",              '\\'                 ],
##[ "Win32->catdir('/', '..\\')",             '\\'                 ],
##[ "Win32->catdir('\\', '../')",             '\\'                 ],
##[ "Win32->catdir('\\', '..\\')",            '\\'                 ],
##[ "Win32->catdir('//d1','d2')",             '\\\\d1\\d2'         ],
##[ "Win32->catdir('\\d1\\','d2')",           '\\d1\\d2'         ],
##[ "Win32->catdir('\\d1','d2')",             '\\d1\\d2'         ],
##[ "Win32->catdir('\\d1','\\d2')",           '\\d1\\d2'         ],
##[ "Win32->catdir('\\d1','\\d2\\')",         '\\d1\\d2'         ],
##[ "Win32->catdir('','/d1','d2')",           '\\d1\\d2'         ],
##[ "Win32->catdir('','','/d1','d2')",        '\\d1\\d2'         ],
##[ "Win32->catdir('','//d1','d2')",          '\\d1\\d2'         ],
##[ "Win32->catdir('','','//d1','d2')",       '\\d1\\d2'         ],
##[ "Win32->catdir('','d1','','d2','')",      '\\d1\\d2'           ],
##[ "Win32->catdir('','d1','d2','d3','')",    '\\d1\\d2\\d3'       ],
##[ "Win32->catdir('d1','d2','d3','')",       'd1\\d2\\d3'         ],
##[ "Win32->catdir('','d1','d2','d3')",       '\\d1\\d2\\d3'       ],
##[ "Win32->catdir('d1','d2','d3')",          'd1\\d2\\d3'         ],
##[ "Win32->catdir('A:/d1','d2','d3')",       'A:\\d1\\d2\\d3'     ],
##[ "Win32->catdir('A:/d1','d2','d3','')",    'A:\\d1\\d2\\d3'     ],
###[ "Win32->catdir('A:/d1','B:/d2','d3','')", 'A:\\d1\\d2\\d3'     ],
##[ "Win32->catdir('A:/d1','B:/d2','d3','')", 'A:\\d1\\B:\\d2\\d3' ],
##[ "Win32->catdir('A:/')",                   'A:\\'               ],
##[ "Win32->catdir('\\', 'foo')",             '\\foo'              ],
##[ "Win32->catdir('','','..')",              '\\'                 ],
##[ "Win32->catdir('A:', 'foo')",             'A:\\foo'            ],
##
##[ "Win32->catfile('a','b','c')",        'a\\b\\c' ],
##[ "Win32->catfile('a','b','.\\c')",      'a\\b\\c'  ],
##[ "Win32->catfile('.\\a','b','c')",      'a\\b\\c'  ],
##[ "Win32->catfile('c')",                'c' ],
##[ "Win32->catfile('.\\c')",              'c' ],
##[ "Win32->catfile('a/..','../b')",       '..\\b' ],
##[ "Win32->catfile('A:', 'foo')",         'A:\\foo'            ],
##
##
##[ "Win32->canonpath('')",               ''                    ],
##[ "Win32->canonpath('a:')",             'A:'                  ],
##[ "Win32->canonpath('A:f')",            'A:f'                 ],
##[ "Win32->canonpath('A:/')",            'A:\\'                ],
### rt.perl.org 27052
##[ "Win32->canonpath('a\\..\\..\\b\\c')", '..\\b\\c'           ],
##[ "Win32->canonpath('//a\\b//c')",      '\\\\a\\b\\c'         ],
##[ "Win32->canonpath('/a/..../c')",      '\\a\\....\\c'        ],
##[ "Win32->canonpath('//a/b\\c')",       '\\\\a\\b\\c'         ],
##[ "Win32->canonpath('////')",           '\\'                  ],
##[ "Win32->canonpath('//')",             '\\'                  ],
##[ "Win32->canonpath('/.')",             '\\'                  ],
##[ "Win32->canonpath('//a/b/../../c')",  '\\\\a\\b\\c'         ],
##[ "Win32->canonpath('//a/b/c/../d')",   '\\\\a\\b\\d'         ],
##[ "Win32->canonpath('//a/b/c/../../d')",'\\\\a\\b\\d'         ],
##[ "Win32->canonpath('//a/b/c/.../d')",  '\\\\a\\b\\d'         ],
##[ "Win32->canonpath('/a/b/c/../../d')", '\\a\\d'              ],
##[ "Win32->canonpath('/a/b/c/.../d')",   '\\a\\d'              ],
##[ "Win32->canonpath('\\../temp\\')",    '\\temp'              ],
##[ "Win32->canonpath('\\../')",          '\\'                  ],
##[ "Win32->canonpath('\\..\\')",         '\\'                  ],
##[ "Win32->canonpath('/../')",           '\\'                  ],
##[ "Win32->canonpath('/..\\')",          '\\'                  ],
##[ "Win32->canonpath('d1/../foo')",      'foo'                 ],
##
### FakeWin32 subclass (see below) just sets CWD to C:\one\two and getdcwd('D') to D:\alpha\beta
##
##[ "FakeWin32->abs2rel('/t1/t2/t3','/t1/t2/t3')",     '.'                      ],
##[ "FakeWin32->abs2rel('/t1/t2/t4','/t1/t2/t3')",     '..\\t4'                 ],
##[ "FakeWin32->abs2rel('/t1/t2','/t1/t2/t3')",        '..'                     ],
##[ "FakeWin32->abs2rel('/t1/t2/t3/t4','/t1/t2/t3')",  't4'                     ],
##[ "FakeWin32->abs2rel('/t4/t5/t6','/t1/t2/t3')",     '..\\..\\..\\t4\\t5\\t6' ],
##[ "FakeWin32->abs2rel('../t4','/t1/t2/t3')",         '..\\..\\..\\one\\t4'    ],  # Uses _cwd()
##[ "FakeWin32->abs2rel('/','/t1/t2/t3')",             '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('///','/t1/t2/t3')",           '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('/.','/t1/t2/t3')",            '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('/./','/t1/t2/t3')",           '..\\..\\..'             ],
##[ "FakeWin32->abs2rel('\\\\a/t1/t2/t4','/t2/t3')",   '\\\\a\\t1\\t2\\t4'      ],
##[ "FakeWin32->abs2rel('//a/t1/t2/t4','/t2/t3')",     '\\\\a\\t1\\t2\\t4'      ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3','A:/t1/t2/t3')",     '.'                  ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3/t4','A:/t1/t2/t3')",  't4'                 ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3','A:/t1/t2/t3/t4')",  '..'                 ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3','B:/t1/t2/t3')",     'A:\\t1\\t2\\t3'     ],
##[ "FakeWin32->abs2rel('A:/t1/t2/t3/t4','B:/t1/t2/t3')",  'A:\\t1\\t2\\t3\\t4' ],
##[ "FakeWin32->abs2rel('E:/foo/bar/baz')",            'E:\\foo\\bar\\baz'      ],
##[ "FakeWin32->abs2rel('C:/one/two/three')",          'three'                  ],
##[ "FakeWin32->abs2rel('C:\\Windows\\System32', 'C:\\')",  'Windows\System32'  ],
##[ "FakeWin32->abs2rel('\\\\computer2\\share3\\foo.txt', '\\\\computer2\\share3')",  'foo.txt' ],
##[ "FakeWin32->abs2rel('C:\\one\\two\\t\\asd1\\', 't\\asd\\')", '..\\asd1'     ],
##[ "FakeWin32->abs2rel('\\one\\two', 'A:\\foo')",     'C:\\one\\two'           ],
##
##[ "FakeWin32->rel2abs('temp','C:/')",                       'C:\\temp'                        ],
##[ "FakeWin32->rel2abs('temp','C:/a')",                      'C:\\a\\temp'                     ],
##[ "FakeWin32->rel2abs('temp','C:/a/')",                     'C:\\a\\temp'                     ],
##[ "FakeWin32->rel2abs('../','C:/')",                        'C:\\'                            ],
##[ "FakeWin32->rel2abs('../','C:/a')",                       'C:\\'                            ],
##[ "FakeWin32->rel2abs('\\foo','C:/a')",                     'C:\\foo'                         ],
##[ "FakeWin32->rel2abs('temp','//prague_main/work/')",       '\\\\prague_main\\work\\temp'     ],
##[ "FakeWin32->rel2abs('../temp','//prague_main/work/')",    '\\\\prague_main\\work\\temp'     ],
##[ "FakeWin32->rel2abs('temp','//prague_main/work')",        '\\\\prague_main\\work\\temp'     ],
##[ "FakeWin32->rel2abs('../','//prague_main/work')",         '\\\\prague_main\\work'           ],
##[ "FakeWin32->rel2abs('D:foo.txt')",                        'D:\\alpha\\beta\\foo.txt'        ],
##
##[ "Cygwin->case_tolerant()",         '1'  ],
##[ "Cygwin->catfile('a','b','c')",         'a/b/c'  ],
##[ "Cygwin->catfile('a','b','./c')",       'a/b/c'  ],
##[ "Cygwin->catfile('./a','b','c')",       'a/b/c'  ],
##[ "Cygwin->catfile('c')",                 'c' ],
##[ "Cygwin->catfile('./c')",               'c' ],
##
##[ "Cygwin->catdir()",                     ''          ],
##[ "Cygwin->catdir('/')",                  '/'         ],
##[ "Cygwin->catdir('','d1','d2','d3','')", '/d1/d2/d3' ],
##[ "Cygwin->catdir('d1','d2','d3','')",    'd1/d2/d3'  ],
##[ "Cygwin->catdir('','d1','d2','d3')",    '/d1/d2/d3' ],
##[ "Cygwin->catdir('d1','d2','d3')",       'd1/d2/d3'  ],
##[ "Cygwin->catdir('/','d2/d3')",     '/d2/d3'  ],
##
##[ "Cygwin->canonpath('///../../..//./././a//b/.././c/././')",   '/a/b/../c' ],
##[ "Cygwin->canonpath('')",                       ''               ],
##[ "Cygwin->canonpath('a/../../b/c')",            'a/../../b/c'    ],
##[ "Cygwin->canonpath('/.')",                     '/'              ],
##[ "Cygwin->canonpath('/./')",                    '/'              ],
##[ "Cygwin->canonpath('/a/./')",                  '/a'             ],
##[ "Cygwin->canonpath('/a/.')",                   '/a'             ],
##[ "Cygwin->canonpath('/../../')",                '/'              ],
##[ "Cygwin->canonpath('/../..')",                 '/'              ],
##
##[  "Cygwin->abs2rel('/t1/t2/t3','/t1/t2/t3')",          '.'                  ],
##[  "Cygwin->abs2rel('/t1/t2/t4','/t1/t2/t3')",          '../t4'              ],
##[  "Cygwin->abs2rel('/t1/t2','/t1/t2/t3')",             '..'                 ],
##[  "Cygwin->abs2rel('/t1/t2/t3/t4','/t1/t2/t3')",       't4'                 ],
##[  "Cygwin->abs2rel('/t4/t5/t6','/t1/t2/t3')",          '../../../t4/t5/t6'  ],
###[ "Cygwin->abs2rel('../t4','/t1/t2/t3')",              '../t4'              ],
##[  "Cygwin->abs2rel('/','/t1/t2/t3')",                  '../../..'           ],
##[  "Cygwin->abs2rel('///','/t1/t2/t3')",                '../../..'           ],
##[  "Cygwin->abs2rel('/.','/t1/t2/t3')",                 '../../..'           ],
##[  "Cygwin->abs2rel('/./','/t1/t2/t3')",                '../../..'           ],
###[ "Cygwin->abs2rel('../t4','/t1/t2/t3')",              '../t4'              ],
##[  "Cygwin->abs2rel('/t1/t2/t3', '/')",                 't1/t2/t3'           ],
##[  "Cygwin->abs2rel('/t1/t2/t3', '/t1')",               't2/t3'              ],
##[  "Cygwin->abs2rel('t1/t2/t3', 't1')",                 't2/t3'              ],
##[  "Cygwin->abs2rel('t1/t2/t3', 't4')",                 '../t1/t2/t3'        ],
##
##[ "Cygwin->rel2abs('t4','/t1/t2/t3')",             '/t1/t2/t3/t4'    ],
##[ "Cygwin->rel2abs('t4/t5','/t1/t2/t3')",          '/t1/t2/t3/t4/t5' ],
##[ "Cygwin->rel2abs('.','/t1/t2/t3')",              '/t1/t2/t3'       ],
##[ "Cygwin->rel2abs('..','/t1/t2/t3')",             '/t1/t2/t3/..'    ],
##[ "Cygwin->rel2abs('../t4','/t1/t2/t3')",          '/t1/t2/t3/../t4' ],
##[ "Cygwin->rel2abs('/t1','/t1/t2/t3')",            '/t1'             ],
##[ "Cygwin->rel2abs('//t1/t2/t3','/foo')",          '//t1/t2/t3'      ],
##
) ;

##
##can_ok('File::Spec::Win32', '_cwd');
##
##{
##    package File::Spec::FakeWin32;
##    use vars qw(@ISA);
##    @ISA = qw(File::Spec::Win32);
##
##    sub _cwd { 'C:\\one\\two' }
##
##    # Some funky stuff to override Cwd::getdcwd() for testing purposes,
##    # in the limited scope of the rel2abs() method.
##    if ($Cwd::VERSION && $Cwd::VERSION gt '2.17') {  # Avoid a 'used only once' warning
##	local $^W;
##	*rel2abs = sub {
##	    my $self = shift;
##	    local $^W;
##	    local *Cwd::getdcwd = sub {
##	      return 'D:\alpha\beta' if $_[0] eq 'D:';
##	      return 'C:\one\two'    if $_[0] eq 'C:';
##	      return;
##	    };
##	    *Cwd::getdcwd = *Cwd::getdcwd; # Avoid a 'used only once' warning
##	    return $self->SUPER::rel2abs(@_);
##	};
##	*rel2abs = *rel2abs; # Avoid a 'used only once' warning
##    }
##}

# Tries a named function with the given args and compares the result against
# an expected result. Works with functions that return scalars or arrays.
for ( @tests ) {
    my ($function, $expected) = @$_;

    $function =~ s#\\#\\\\#g ;
    my $got = join ',', eval $function;

 SKIP: {
	if ($@) {
	    is($@, '', $function);
	} else {
	    is($got, $expected, $function);
	}
    }
}

done_testing;
# COPYRIGHT
