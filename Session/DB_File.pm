package CGI::Session::DB_File;

# $Id$

use strict;
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default
);

use DB_File;
use File::Spec;
use Fcntl (':DEFAULT', ':flock');

# Load neccessary libraries below

use vars qw($VERSION $FILE_NAME);
$FILE_NAME = 'cgisess.db';

$VERSION = '0.1';

sub store {
    my ($self, $sid, $options, $data) = @_;

    my $storable_data = $self->freeze($data);

    my $args = $options->[1];
    my $file = File::Spec->catfile($args->{Directory}, $args->{FileName} || $FILE_NAME);

    tie my %db, "DB_File", $file, O_RDWR|O_CREAT, 0600 or die $!;
    $db{$sid} = $storable_data;
    untie(%db) or die $!;

    return 1;
}


sub retrieve {
    my ($self, $sid, $options) = @_;

    # you will need to retrieve the stored data, and
    # deserialize it using $self->thaw() method

    my $args = $options->[1];
    my $file = File::Spec->catfile($args->{Directory}, $args->{FileName} || $FILE_NAME);

    tie my %db, "DB_File", $file, O_RDWR|O_CREAT, 0600 or die $!;
    unless ( $db{$sid} ) {
        return undef;
    }
    my $data = $self->thaw($db{$sid});
    untie(%db);

    return $data;
}



sub remove {
    my ($self, $sid, $options) = @_;

    # you simply need to remove the data associated
    # with the id

    my $args = $options->[1];
    my $file = File::Spec->catfile($args->{Directory}, $args->{FileName} || $FILE_NAME);
    tie my %db, "DB_File", $file, O_RDWR or die $!;
    delete $db{$sid};
    untie(%db) or die $!;

    return 1;
}



sub teardown {
    my ($self, $sid, $options) = @_;

    # this is called just before session object is destroyed
}




# $Id$

1;

=pod

=head1 NAME

CGI::Session::DB_File - DB_File driver for CGI::Session

=head1 SYNOPSIS

    use CGI::Session;
    $session = new CGI::Session("driver:DB_File", undef, {Directory=>'/tmp'});

For more details, refer to L<CGI::Session> manual

=head1 DESCRIPTION

CGI::Session::DB_File is a CGI::Session driver to store session data in BerkeleyDB.
Filename to store the session data is by default 'cgisess.db'. If you want different
name, you can either specify it with the "FileName" option as below:

    $s = new CGI::Session::DB_File(undef, {Directory=>'/tmp', FileName=>'sessions.db'});

or by setting the value of the $CGI::Session::DB_File::NAME variable before creating
the session object:

    $CGI::Session::DB_File::NAME = 'sessions.db';
    $s = new CGI::Session("driver:DB_File", undef, {Directory=>'/tmp'});

The only driver option required, as in the above examples, is "Directory", which tells the
driver where the session file and lock files should be created.

"FileName" option is also available, but not required.

=head1 COPYRIGHT

Copyright (C) 2001-2002 Sherzod Ruzmetov. All rights reserved.

This library is free software and can be modified and distributed under the same
terms as Perl itself.

Bug reports should be directed to sherzodr@cpan.org, or posted to Cgi-session@ultracgis.com
mailing list.

=head1 AUTHOR

CGI::Session::DB_File is written and maintained by Sherzod Ruzmetov <sherzodr@cpan.org>

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
