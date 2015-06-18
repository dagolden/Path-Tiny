use 5.008001;
use strict;
use warnings;

package Path::TinyUtil;

our $VERSION = '0.070';

use parent 'File::Spec';

=head1 abs2rel

Method Stolen out of recent File::Spec to permit use of older File::Spec versions
to continue supporting Perl 5.8.

=item abs2rel

Takes a destination path and an optional base path returns a relative path
from the base path to the destination path:

    $rel_path = File::Spec->abs2rel( $path ) ;
    $rel_path = File::Spec->abs2rel( $path, $base ) ;

If $base is not present or '', then L<cwd()|Cwd> is used. If $base is
relative, then it is converted to absolute form using
L</rel2abs()>. This means that it is taken to be relative to
L<cwd()|Cwd>.

On systems that have a grammar that indicates filenames, this ignores the 
$base filename. Otherwise all path components are assumed to be
directories.

If $path is relative, it is converted to absolute form using L</rel2abs()>.
This means that it is taken to be relative to L<cwd()|Cwd>.

No checks against the filesystem are made, so the result may not be correct if
C<$base> contains symbolic links.  (Apply
L<Cwd::abs_path()|Cwd/abs_path> beforehand if that
is a concern.)  On VMS, there is interaction with the working environment, as
logicals and macros are expanded.

Based on code written by Shigio Yamaguchi.

=cut

sub abs2rel {
    my($self,$path,$base) = @_;
    $base = $self->_cwd() unless defined $base and length $base;

    ($path, $base) = map $self->canonpath($_), $path, $base;

    my $path_directories;
    my $base_directories;

    if (grep $self->file_name_is_absolute($_), $path, $base) {
	($path, $base) = map $self->rel2abs($_), $path, $base;

	my ($path_volume) = $self->splitpath($path, 1);
	my ($base_volume) = $self->splitpath($base, 1);

	# Can't relativize across volumes
	return $path unless $path_volume eq $base_volume;

	$path_directories = ($self->splitpath($path, 1))[1];
	$base_directories = ($self->splitpath($base, 1))[1];

	# For UNC paths, the user might give a volume like //foo/bar that
	# strictly speaking has no directory portion.  Treat it as if it
	# had the root directory for that volume.
	if (!length($base_directories) and $self->file_name_is_absolute($base)) {
	    $base_directories = $self->rootdir;
	}
    }
    else {
	my $wd= ($self->splitpath($self->_cwd(), 1))[1];
	$path_directories = $self->catdir($wd, $path);
	$base_directories = $self->catdir($wd, $base);
    }

    # Now, remove all leading components that are the same
    my @pathchunks = $self->splitdir( $path_directories );
    my @basechunks = $self->splitdir( $base_directories );

    if ($base_directories eq $self->rootdir) {
      return $self->curdir if $path_directories eq $self->rootdir;
      shift @pathchunks;
      return $self->canonpath( $self->catpath('', $self->catdir( @pathchunks ), '') );
    }

    my @common;
    while (@pathchunks && @basechunks && $self->_same($pathchunks[0], $basechunks[0])) {
        push @common, shift @pathchunks ;
        shift @basechunks ;
    }
    return $self->curdir unless @pathchunks || @basechunks;

    # @basechunks now contains the directories the resulting relative path 
    # must ascend out of before it can descend to $path_directory.  If there
    # are updir components, we must descend into the corresponding directories
    # (this only works if they are no symlinks).
    my @reverse_base;
    while( defined(my $dir= shift @basechunks) ) {
	if( $dir ne $self->updir ) {
	    unshift @reverse_base, $self->updir;
	    push @common, $dir;
	}
	elsif( @common ) {
	    if( @reverse_base && $reverse_base[0] eq $self->updir ) {
		shift @reverse_base;
		pop @common;
	    }
	    else {
		unshift @reverse_base, pop @common;
	    }
	}
    }
    my $result_dirs = $self->catdir( @reverse_base, @pathchunks );
    return $self->canonpath( $self->catpath('', $result_dirs, '') );
}