package CGI::Session::DB_File;

# $Id$

use DB_File;
use File::Spec;
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default );

use vars qw($VERSION $NAME);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;
$NAME = 'cgisess.db';


sub retrieve {
    my ($self, $sid, $options) = @_;
    
    my $db = $self->DB_File_init($options) or return;
    
    if ( defined $db->{$sid} ) {
        return $self->thaw( $db->{$sid} );
    }

    return undef;
}


sub store {
    my ($self, $sid, $options, $data) = @_;

    my $db = $self->DB_File_init($options) or return;
    return $db->{$sid} = $self->freeze($data);    
}




sub remove {
    my ($self, $sid, $options) = @_;

    my $db = $self->DB_File_init($options);
    return delete $db->{$sid};
}



sub teardown {
    my ($self, $sid, $options) = @_;

    if ( defined $self->{_db_file_hash} ) {
        untie(%{$self->{_db_file_hash}} );
    }    
}



sub DB_File_init {
    my ($self, $options) = @_;

    if ( defined $self->{_db_file_hash} ) {
        return $self->{_db_file_hash};
    }

    my $dir = $options->[1]->{Directory};
    my $file= $options->[1]->{FileName} || $NAME;
    my $path= File::Spec->catfile($dir, $file);

    unless ( tie (my %db, "DB_File", $path, O_RDWR|O_CREAT, 0644, $DB_HASH) ) {
        $self->error("Couldn't open $path: $!");
        return undef;
    }
    $self->{_db_file_hash} = \%db;
    $self->{_db_file_path} = $path;

    return $self->{_db_file_hash};
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

L<CGI::Session>
L<CGI::Session::MySQL>
L<CGI::Session::DB_File>
L<CGI::Session::BerkelyDB>

=cut

# $Id$
