package CGI::Session::BluePrint;

# $Id$

# Inheriting necessary functionalities from the 
# following libraries. Do not change it unless you know
# what you are doing
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Storable    
);


# driver specific libraries should go below



use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;


########################
# driver methods follow
########################


# stores the serialized data. Returns 1 for sucess, undef otherwise
sub store {
    my ($self, $sid, $options, $data) = @_;
    
    my $serialized_data = $self->freeze($data);

}



# retrieves the serialized data and deserializes it
sub retrieve {
    my ($self, $sid, $options) = @_;

    # after you get the data, deserialize it using
    # $self->thaw(), and return it
    

}


# removes the given data and all the disk space associated with it
sub remove {
    my ($self, $sid, $options) = @_;
    
}




# called right before the object is destroyed to do cleanup
sub teardown {
    my ($self, $sid, $options) = @_;

    return 1;
}




# $Id$

1;       

=pod

=head1 NAME

CGI::Session::BluePrint - BluePrint for your driver. Your better edit it!

=head1 REVISION

This manual refers to $Revision$

=head1 SYNOPSIS
    
    use CGI::Session::BluePrint;    
    $session = new CGI::Session::BluePrint(undef, {});

    # For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

It looks like the author of of the driver was negligent enough to leave the stub undefined.

=head1 COPYRIGHT

Copyright (C) 2001-2002 Your Name. All rights reserved.

This library is free software and can be modified and distributed under the same
terms as Perl itself. 

Bug reports should be directed to sherzodr@cpan.org, or posted to Cgi-session@ultracgis.com
mailing list.

=head1 AUTHOR

Names

=head1 SEE ALSO

L<CGI::Session>
L<CGI::Session::MySQL>
L<CGI::Session::DB_File>
L<CGI::Session::BerkelyDB>

=cut


# $Id$
