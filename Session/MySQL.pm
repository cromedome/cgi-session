package CGI::Session::MySQL;

# $Id$

use strict;
# Inheriting necessary functionalities from the 
# following libraries. Do not change it unless you know
# what you are doing
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default
);


# driver specific libraries should go below

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
        $self->error("Couldn't acquire lock on id '$sid'. Lock status: $lck_status");
        return undef;
    }

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
        $self->error("Couldn't acquire lock on is '$sid'. Lock status: $lck_status");
        return undef;
    }

    my $data = $dbh->selectrow_array(qq|SELECT a_session FROM $TABLE_NAME WHERE id=?|, undef, $sid);
    $lck_status = $dbh->selectrow_array(qq|SELECT RELEASE_LOCK("$sid")|);
    unless ( $lck_status == 1 ) {
        $self->error("Couldn't release lock of '$sid'. Lock status: $lck_status");
        return undef;
    }

    return $self->thaw($data);
}


# removes the given data and all the disk space associated with it
sub remove {
    my ($self, $sid, $options) = @_;

    my $dbh = $self->MySQL_dbh($options);
    my $lck_status = $dbh->selectrow_array(qq|SELECT GET_LOCK("$sid", 10)|);
    unless ( $lck_status == 1 ) {
        $self->error("Couldn't acquire lock on id '$sid'. Lock status; $lck_status");
        return undef;
    }

    $dbh->do(qq|DELETE FROM $TABLE_NAME WHERE id=?|, undef, $sid);
    $lck_status = $dbh->selectrow_array(qq|SELECT RELEASE_LOCK("$sid")|);
    unless ( $lck_status == 1 ) {
        $self->error("Couldn't release lock of '$sid'. Lock status: $lck_status");
        return undef;
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
    
    if ( defined $self->{MySQL_dbh} ) {
        return $self->{MySQL_dbh};

    }
    
    require DBI;

    $self->{MySQL_dbh} = $args->{Handle} || DBI->connect(
                    $args->{DataSource},
                    $args->{User}       || undef, 
                    $args->{Password}   || undef, 
                    { RaiseError=>1, PrintError=>1, AutoCommit=>1 } );

    # If we're the one established the connection, 
    # we should be the one who closes it    
    $args->{Handle} or $self->{MySQL_disconnect} = 1;
    return $self->{MySQL_dbh};
    
}




# $Id$

1;       
=pod

=head1 NAME

CGI::Session::MySQL - MySQL driver for  CGI::Session

=head1 SYNOPSIS
    
    use CGI::Session qw/-api3/;
    $session = new CGI::Session("driver:MySQL", undef, {Handle=>$dbh});

For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

CGI::Session::MySQL is a CGI::Session driver to store session data in MySQL table.
To write your own drivers for B<CGI::Session> refere L<CGI::Session> manual.


=head1 STORAGE

To store session data in MySQL database, you first need to create a suitable table for it
with the following command:

    CREATE TABLE sessions (
        id CHAR(32) NOT NULL,
        a_session TEXT NOT NULL
    );


You can also add any number of additional columns to the table, but the above "id"
and "a_session" are required. 

If you want to store the session data in other table than "sessions", before creating
the session object you need to set the special variable B<$CGI::Session::MySQL::TABLE_NAME>
to the name of the table:

    use CGI::Session qw/-api3/;

    $CGI::Session::MySQL::TABLE_NAME = 'my_sessions';
    $session = new CGI::Session("driver:MySQL", undef, {Handle=>$dbh});

=head1 COPYRIGHT

Copyright (C) 2001, 2002 Sherzod Ruzmetov. All rights reserved.

This library is free software and can be modified and distributed under the same
terms as Perl itself. 


=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>. All the bug reports should be sent to the author
to sherzodr@cpan.org>

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
