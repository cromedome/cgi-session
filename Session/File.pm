package CGI::Session::File;

# $Id$

use strict;
use File::Spec;
use Fcntl (':DEFAULT', ':flock');
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default
);

use vars qw($FileName $VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;
$FileName = 'cgisess_%s';

sub store {
    my ($self, $sid, $options, $data) = @_;

    $self->File_init($sid, $options);
    unless ( sysopen (FH, $self->{_file_path}, O_RDWR|O_CREAT, 0644) ) {
        $self->error("Couldn't store $sid into $self->{_file_path}: $!");
        return undef;
    }
    unless (flock(FH, LOCK_EX) ) {
        $self->error("Couldn't get LOCK_EX: $!");
        return undef;
    }
    print FH $self->freeze($data);    
    unless ( close(FH) ) {
        $self->error("Couldn't close $self->{_file_path}: $!");
        return undef;
    }
    return 1;
}


sub retrieve {
    my ($self, $sid, $options) = @_;

    $self->File_init($sid, $options);

    # If the session data does not exist, return.
    unless ( -e $self->{_file_path} ) {
        return undef;
    }

    unless ( sysopen(FH, $self->{_file_path}, O_RDONLY) ) {
        $self->error("Couldn't open $self->{_file_path}: $!");
        return undef;
    }
    unless (flock(FH, LOCK_SH) ) {
        $self->error("Couldn't lock the file: $!");
        return undef;
    }
    my $data = '';
    while ( <FH> ) {
        $data .= $_;
    }
    close(FH);
    return $self->thaw($data);
}



sub remove {
    my ($self, $sid, $options) = @_;
    
    $self->File_init($sid, $options);
    unless ( unlink ( $self->{_file_path} ) ) {
        $self->error("Couldn't unlink $self->{_file_path}: $!");
        return undef;
    }
    return 1;
}



sub teardown {
    my ($self, $sid, $options) = @_;

    return 1;
}




sub File_init {
    my ($self, $sid, $options) = @_;

    my $dir = $options->[1]->{Directory};
    my $path = File::Spec->catfile($dir, sprintf("$FileName", $sid));
    $self->{_file_path} = $path;    
}






# $Id$

1;       

=pod

=head1 NAME

CGI::Session::File - Default CGI::Session driver

=head1 REVISION

This manual refers to $Revision$

=head1 SYNOPSIS
    
    use CGI::Session::File;    
    $session = new CGI::Session::File(undef, {Directory=>'/tmp'});

For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

CGI::Session::File is a default CGI::Session driver. Stores the session data
in plain files. For the list of available methods, consult L<CGI::Session> manual.

Each session is stored in a seperate file. File name is by default formatted as "cgisess_%s",
where '%s' is replaced with the effective session id. To change file name formatting,
update $CGI::Session::File::NAME variable. Examples:

    $CGI::Session::File::FileName = 'cgisess_%s.dat';       # with .dat extention
    $CGI::Session::File::FileName = '%s.session';
    $CGI::Session::File::FileName = '%CGI-Session-%s.dat';  # old style

The only driver option required is 'Directory', which denotes the location 
session files are stored in.

Example:

    $session = new CGI::Session::File(undef, {Directory=>'some/directory'});

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
