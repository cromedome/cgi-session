package CGI::Session::BluePrint;

# $Id$

use strict;
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default
);


# Load neccessary libraries below

use vars qw($VERSION);

$VERSION = '0.1';

sub store {
    my ($self, $sid, $options, $data) = @_;

    my $storable_data = $self->freeze($data);

    #now you need to store the $storable_data into the disk

}


sub retrieve {
    my ($self, $sid, $options) = @_;

    # you will need to retrieve the stored data, and 
    # deserialize it using $self->thaw() method
}



sub remove {
    my ($self, $sid, $options) = @_;

    # you simply need to remove the data associated 
    # with the id
    
    
}



sub teardown {
    my ($self, $sid, $options) = @_;

    # this is called just before session object is destroyed
}




# $Id$

1;       

=pod

=head1 NAME

CGI::Session::BluePrint - Default CGI::Session driver BluePrint

=head1 SYNOPSIS
    
    use CGI::Session::BluePrint
    $session = new CGI::Session("driver:BluePrint", undef, {...});

For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

CGI::Session::BluePrint is a CGI::Session driver.
To write your own drivers for B<CGI::Session> refere L<CGI::Session> manual.

=head1 COPYRIGHT

Copyright (C) 2002 Your Name. All rights reserved.

This library is free software and can be modified and distributed under the same
terms as Perl itself. 

=head1 AUTHOR

Your name

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session|CGI::Session> - CGI::Session manual

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut


# $Id$
