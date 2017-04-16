package Path::Tiny::Encrypt::ROT13;

use parent 'Exporter';

our @EXPORT = qw/ spew_rot13 slurp_rot13 /;

sub spew_rot13 {
    my( $self, @data ) = @_;

    y/A-Za-z/N-ZA-Mn-za-m/ for @data;

    $self->spew(@data);
}

sub slurp_rot13 {
    my $self = shift;

    my $content = $self->slurp;
    $content =~ y/A-Za-z/N-ZA-Mn-za-m/;

    return $content;
}

1;
