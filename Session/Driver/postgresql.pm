package CGI::Session::Driver::postgresql;
# CGI::Session::Driver::postgresql - PostgreSQL driver for CGI::Session
#
# Copyright (C) 2001-2002 Sherzod Ruzmetov, sherzodr@cpan.org
#
# Copyright (C) 2002 Cosimo Streppone, cosimo@cpan.org
# This module is based on CGI::Session::Driver::mysql module
# by Sherzod Ruzmetov, original author of CGI::Session modules
# and CGI::Session::Driver::mysql driver.
#
# $Id$


use strict;
use diagnostics;

use CGI::Session::Driver::DBI;
use vars qw( $VERSION @ISA );

$VERSION = '2.01';
@ISA     = qw( CGI::Session::Driver::DBI );


# $Id$

1;

=pod

=head1 NAME

CGI::Session::Driver::postgresql - PostgreSQL driver for CGI::Session

=head1 SYNOPSIS

    use CGI::Session;
    $session = new CGI::Session("driver:PostgreSQL", undef, {Handle=>$dbh});

=head1 DESCRIPTION

CGI::Session::PostgreSQL is a CGI::Session driver to store session data in a PostgreSQL table. More details see L<CGI::Session::Driver::DBI|CGI::Session::Driver::DBI>, its parent class.

=head1 COPYRIGHT

Copyright (C) 2002 Cosimo Streppone. All rights reserved. This library is free software and can be modified and distributed under the same terms as Perl itself.

=head1 AUTHOR

Cosimo Streppone <cosimo@cpan.org>, heavily based on the CGI::Session::MySQL driver by Sherzod Ruzmetov, original author of CGI::Session.

=head1 LICENSING

For additional support and licensing see L<CGI::Session|CGI::Session>

=cut
