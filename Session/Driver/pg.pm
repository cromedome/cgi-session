package CGI::Session::Driver::pg;
# CGI::Session::PostgreSQL - PostgreSQL driver for CGI::Session
#
# Copyright (C) 2001-2002 Sherzod Ruzmetov, sherzodr@cpan.org
#
# Copyright (C) 2002 Cosimo Streppone, cosimo@cpan.org
# This module is based on CGI::Session::MySql module
# by Sherzod Ruzmetov, original author of CGI::Session modules
# and CGI::Session::MySQL driver.
#
# $Id$


use strict;
use CGI::Session::Driver::DBI;
use vars qw( $VERSION @ISA );

$VERSION = '2.01';
@ISA     = qw( CGI::Session::Driver::DBI );

$CGI::Session::Driver::pg::TABLE_NAME = 'sessions';


sub table_name { $TABLE_NAME }






# $Id$

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
