# CGI::Session::PostgreSQL - PostgreSQL driver for CGI::Session
#
# Copyright (C) 2001-2002 Sherzod Ruzmetov, sherzodr@cpan.org
#
# Copyright (C) 2002 Cosimo Streppone, cosimo@cpan.org
# This module is based on CGI::Session::MySql module
# by Sherzod Ruzmetov, original author of CGI::Session modules
# and CGI::Session::MySQL driver.
#
# $Id: PostgreSQL.pm,v 1.1 2002/12/08 19:37:34 cosimo Exp $

package CGI::Session::PostgreSQL;

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

($VERSION) = '$Revision: 1.1 $' =~ m/Revision:\s*(\S+)/;
$TABLE_NAME = 'sessions';

########################
# Driver methods follow
########################


# stores the serialized data. Returns 1 for sucess, undef otherwise
sub store {

	my ($self, $sid, $options, $data) = @_;
	my $dbh = $self->PostgreSQL_dbh($options);
	my $db_data;

	eval {

		($db_data) = $dbh->selectrow_array(
			#' SELECT FOR UPDATE a_session FROM '.$TABLE_NAME.
			' SELECT a_session FROM '.$TABLE_NAME.
			' WHERE id = '.$dbh->quote($sid)
		);

	};

	if( $@ ) {
		$self->error("Couldn't acquire data on id '$sid'");
		return undef;
	}

	eval {

		if( $db_data ) {

#warn('do update sid='.$sid.' data='.$self->freeze($data));

			$dbh->do(
				' UPDATE '.$TABLE_NAME.
				' SET a_session='.$dbh->quote($self->freeze($data)).
				' WHERE id='.$dbh->quote($sid)
			);

		} else {

#warn('do insert sid='.$sid.' data='.$self->freeze($data));

			$dbh->do(
				'INSERT INTO '.$TABLE_NAME.' (id,a_session) '.
				'VALUES ('.$dbh->quote($sid).', '.$dbh->quote($self->freeze($data)).')'
			);

		}

	};

	if( $@ ) {
		$self->error("Error in session update on id '$sid'. $@");
		warn("Error in session update on id '$sid'. $@");
		return undef;
	}

	return 1;
}



# retrieves the serialized data and deserializes it
sub retrieve {
    my ($self, $sid, $options) = @_;

    # after you get the data, deserialize it using
    # $self->thaw(), and return it
    my $dbh = $self->PostgreSQL_dbh($options);
	my $data;
    eval {
    	$data = $dbh->selectrow_array(
    		' SELECT a_session FROM '.$TABLE_NAME.
			' WHERE id = '.$dbh->quote($sid)
	    );
	};
	if( $@ ) {
        $self->error("Couldn't acquire data on id '$sid'");
        return undef;
    }
    return $self->thaw($data);
}


# removes the given data and all the disk space associated with it
sub remove {
    my ($self, $sid, $options) = @_;

    my $dbh = $self->PostgreSQL_dbh($options);
    my $data;
    eval {
    	$data = $dbh->selectrow_array(
#    		' SELECT FOR UPDATE a_session FROM '.$TABLE_NAME.' WHERE id = ?',
    		' SELECT a_session FROM '.$TABLE_NAME.
			' WHERE id = '.$dbh->quote($sid)
	    );
	};
	if( $@ ) {
        $self->error("Couldn't acquire data on id '$sid'");
        return undef;
    }

	eval {
		$dbh->do(
    			'DELETE FROM '.$TABLE_NAME.' WHERE id = '.$dbh->quote($sid)
		);
	};
	if( $@ ) {
		$self->error("Couldn't release lock of '$sid'");
		return undef;
	}

    return 1;

}




# Called right before the object is destroyed to do cleanup
sub teardown {
	my ($self, $sid, $options) = @_;

	my $dbh = $self->PostgreSQL_dbh($options);

	# Call commit if it isn't meant to be autocommited!
	unless ( $dbh->{AutoCommit} ) {
		$dbh->commit();
	}

	if ( $self->{PostgreSQL_disconnect} ) {
		$dbh->disconnect();
	}

	return 1;
}


sub PostgreSQL_dbh {
    my ($self, $options) = @_;

    my $args = $options->[1] || {};

    if ( defined $self->{PostgreSQL_dbh} ) {
        return $self->{PostgreSQL_dbh};

    }

	if ( defined $args->{TableName} ) {
		$TABLE_NAME = $args->{TableName};
	}

    require DBI;

    $self->{PostgreSQL_dbh} = $args->{Handle} || DBI->connect(
                    $args->{DataSource},
                    $args->{User}       || undef,
                    $args->{Password}   || undef,
                    { RaiseError=>1, PrintError=>1, AutoCommit=>1 } );

    # If we're the one established the connection,
    # we should be the one who closes it
    $args->{Handle} or $self->{PostgreSQL_disconnect} = 1;

    return $self->{PostgreSQL_dbh};

}




# $Id: PostgreSQL.pm,v 1.1 2002/12/08 19:37:34 cosimo Exp $

1;

=pod

=head1 NAME

CGI::Session::PostgreSQL - PostgreSQL driver for CGI::Session

=head1 SYNOPSIS

    use CGI::Session;
    $session = new CGI::Session("driver:PostgreSQL", undef, {Handle=>$dbh});

For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

CGI::Session::PostgreSQL is a CGI::Session driver to store session data in a PostgreSQL table. To write your own drivers for B<CGI::Session> refere L<CGI::Session> manual.

=head1 STORAGE

To store session data in PostgreSQL database, you first need
to create a suitable table for it with the following command:

    CREATE TABLE sessions (
        id CHAR(32) NOT NULL,
        a_session TEXT NOT NULL
    );


You can also add any number of additional columns to the table,
but the above "id" and "a_session" are required.
If you want to store the session data in other table than "sessions",
you will also need to specify B<TableName> attribute as the
first argument to new():

    use CGI::Session;

    $session = new CGI::Session("driver:PostgreSQL", undef,
						{Handle=>$dbh, TableName=>'my_sessions'});

=head1 COPYRIGHT

Copyright (C) 2002 Cosimo Streppone. All rights reserved.

This library is free software and can be modified and distributed
under the same terms as Perl itself.

=head1 AUTHOR

Cosimo Streppone <cosimo@cpan.org>, heavily based on the CGI::Session::MySQL
driver by Sherzod Ruzmetov, original author of CGI::Session.

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
