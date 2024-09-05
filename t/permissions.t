#!/usr/bin/perl

use strict;
use warnings;
use Path::Tiny;
use Test::More;

# Create a quick temp file with the right permissions
my $file = "/tmp/foo.txt";
file_put_contents($file, "Hello world");
chmod(0764, $file);

my $path = path($file);

# We may need to wrap these tests to NOT run on OSs that do not
# support permissions?

##################################
# permissions()
##################################
is($path->permissions()       , 33268, 'Get permissions');
is($path->permissions('user') , 7    , 'Get permissions user');
is($path->permissions('group'), 6    , 'Get permissions group');
is($path->permissions('other'), 4    , 'Get permissions other');
is($path->permissions('bogus'), undef, 'Get permissions bogus');
is($path->permissions('octal'), '764', 'Get permissions octal');

##################################
# is_readable()
##################################
is($path->is_readable('user') , 1    , 'Is readable user');
is($path->is_readable('group'), 1    , 'Is readable group');
is($path->is_readable('other'), 1    , 'Is readable other');
is($path->is_readable('bogus'), undef, 'Is readable bogus');

##################################
# is_writeable()
##################################
is($path->is_writeable('user') , 1    , 'Is writeable user');
is($path->is_writeable('group'), 1    , 'Is writeable group');
is($path->is_writeable('other'), 0    , 'Is writeable other');
is($path->is_writeable('bogus'), undef, 'Is writeable bogus');

##################################
# is_executable()
##################################
is($path->is_executable('user') , 1    , 'Is executable user');
is($path->is_executable('group'), 0    , 'Is executable group');
is($path->is_executable('other'), 0    , 'Is executable other');
is($path->is_executable('bogus'), undef, 'Is executable bogus');

# Remove our test file
unlink($file);

done_testing();

####################################################################
####################################################################

sub file_put_contents {
	my ($file, $data) = @_;

	open(my $fh, ">", $file) or return undef;
	binmode($fh, ":encoding(UTF-8)");
	print $fh $data;
	close($fh);

	return length($data);
}
