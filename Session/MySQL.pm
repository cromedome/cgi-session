package CGI::Session::MySQL;

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
use Carp "croak";
use vars qw($VERSION $TABLE_NAME);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;

$TABLE_NAME = 'sessions';

########################
# Driver methods follow
########################


# stores the serialized data. Returns 1 for sucess, undef otherwise
sub store {
    my ($self, $sid, $options, $data) = @_;   

    my $dbh = $self->MySQL_dbh($options);
    my $lck_status = $dbh->selectrow_array(qq|SELECT GET_LOCK("$sid", 10)|);
    unless ( $lck_status == 1 ) {
        croak "Couldn't acquire lock on id '$sid'. Lock status: $lck_status";    }

    $dbh->do(qq|REPLACE INTO $TABLE_NAME (id, a_session) VALUES(?,?)|, 
                undef, $sid, $self->freeze($data));
    
    return $dbh->selectrow_array(qq|SELECT RELEASE_LOCK("$sid")|);
}



# retrieves the serialized data and deserializes it
sub retrieve {
    my ($self, $sid, $options) = @_;

    # after you get the data, deserialize it using
    # $self->thaw(), and return it
    my $dbh = $self->MySQL_dbh($options);
    my $lck_status  = $dbh->selectrow_array(qq|SELECT GET_LOCK("$sid", 10)|);
    unless ( $lck_status == 1 ) {
        croak "Couldn't acquire lock on is '$sid'. Lock status: $lck_status";
    }

    my $data = $dbh->selectrow_array(qq|SELECT a_session FROM $TABLE_NAME WHERE id=?|, undef, $sid);
    $lck_status = $dbh->selectrow_array(qq|SELECT RELEASE_LOCK("$sid")|);
    unless ( $lck_status == 1 ) {
        croak "Couldn't release lock of '$sid'. Lock status: $lck_status";
    }

    return $self->thaw($data);
}


# removes the given data and all the disk space associated with it
sub remove {
    my ($self, $sid, $options) = @_;

    $dbh = $self->MySQL_dbh($options);
    my $lck_status = $dbh->selectrow_array(qq|SELECT GET_LOCK("$sid", 10)|);
    unless ( $lck_status == 1 ) {
        croak "Couldn't acquire lock on id '$sid'. Lock status; $lck_status";
    }

    $dbh->do(qq|DELETE FROM $TABLE_NAME WHERE id=?|, undef, $sid);
    $lck_status = $dbh->selectrow_array(qq|SELECT RELEASE_LOCK("$sid")|);
    unless ( $lck_status == 1 ) {
        croak "Couldn't release lock of '$sid'. Lock status: $lck_status";
    }
    
    return 1;    
}




# called right before the object is destroyed to do cleanup
sub teardown {
    my ($self, $sid, $options) = @_;

    my $dbh = $self->MySQL_dbh($options);

    # Call commit if it isn't meant to be autocommited!
    unless ( $dbh->{AutoCommit}  ) {
        $dbh->commit();
    }
    
    if ( $self->{MySQL_disconnect} ) {
        $dbh->disconnect();
    }

    return 1;
}






sub MySQL_dbh {
    my ($self, $options) = @_;

    my $args = $options->[1] || {};

    if ( defined $args->{Handle} ) {
        return $args->{Handle};
    }

    if ( defined $self->{MySQL_dbh} ) {
        return $self->{MySQL_dbh};

    }

    require DBI;

    my $dbh = DBI->connect(
        $args->{DataSource}, 
        $args->{User}, 
        $args->{Password}, 
        { RaiseError=>1, PrintError=>1, AutoCommit=>1 } );

    # If we're the one connected, we should be the one who closes
    # the connection
    $self->{MySQL_disconnect} = 1;
    $self->{MySQL_dbh} = $dbh;

    return $dbh;
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
