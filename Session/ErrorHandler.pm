package CGI::Session::ErrorHandler;

use strict;
use vars qw( $ERRSTR );

sub error {
    $ERRSTR = $_[1] || "";
    return undef;
}

sub errstr {
    return $ERRSTR;
}

1;
