package CGI::Session::Serialize::Storable;

# $Id$ 
use strict;
use Storable;

sub freeze {
    my ($self, $data) = @_;

    return Storable::freeze($data);
}


sub thaw {
    my ($self, $string) = @_;

    return Storable::thaw($string);
}

1;

