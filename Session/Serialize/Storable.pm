package CGI::Session::Serialize::Storable;

# $Id$ 
use strict;
use Storable;
use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;


sub freeze {
    my ($self, $data) = @_;

    return Storable::freeze($data);
}


sub thaw {
    my ($self, $string) = @_;

    return Storable::thaw($string);
}

1;

