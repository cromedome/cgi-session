package CGI::Session::ID::MD5;

# $Id$

use strict;
use Digest::MD5;
use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;

sub generate_id {
    my $self = shift;

    my $md5 = new Digest::MD5();
    $md5->add($$ , time() , rand(9999) );

    return $md5->hexdigest();
}


1;


