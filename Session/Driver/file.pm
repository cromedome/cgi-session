package CGI::Session::Driver::file;

# $Id$

use strict;
#use diagnostics;

use File::Spec;
use Fcntl qw(:DEFAULT :flock);
use CGI::Session::Driver;
use vars qw( $FileName);

@CGI::Session::Driver::file::ISA        = qw( CGI::Session::Driver );
$CGI::Session::Driver::file::VERSION    = "3.2";
$FileName                               = "cgisess_%s";

sub init {
    my $self = shift;
    $self->{Directory} ||= File::Spec->tmpdir();

    unless ( -d $self->{Directory} ) {
        require File::Path;
        unless ( File::Path::mkpath($self->{Directory}) ) {
            return $self->set_error( "init(): couldn't create directory path: $!" );
        }
    }
}




sub retrieve {
    my $self = shift;
    my ($sid) = @_;

    my $directory   = $self->{Directory};
    my $file        = sprintf( $FileName, $sid );
    my $path        = File::Spec->catfile($directory, $file);

    return 0 unless -e $path;

    unless ( sysopen(FH, $path, O_RDONLY) ) {
        return $self->set_error( "retrieve(): couldn't open '$path': $!" );
    }
    my $rv = "";
    while ( <FH> ) {
        $rv .= $_;
    }
    close(FH);
    return $rv;
}



sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    
    my $directory = $self->{Directory};
    my $file      = sprintf( $FileName, $sid );
    my $path      = File::Spec->catfile($directory, $file);
    sysopen(FH, $path, O_WRONLY|O_CREAT|O_TRUNC) or return $self->set_error( "store(): couldn't open '$path': $!" );
    flock(FH, LOCK_EX) or return $self->set_error( "store(): couldn't lock '$path': $!" );
    print FH $datastr;
    close(FH) or return $self->set_error( "store(): couldn't close '$path': $!" );
    return 1;
}


sub remove {
    my $self = shift;
    my ($sid) = @_;

    my $directory = $self->{Directory};
    my $file      = sprintf( $FileName, $sid );
    my $path      = File::Spec->catfile($directory, $file);
    unlink($path) or return $self->set_error( "remove(): couldn't unlink '$path': $!" );
    return 1;
}





sub DESTROY {
    my $self = shift;

}

1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::file - Default CGI::Session driver

=head1 SYNOPSIS

    $s = new CGI::Session();
    $s = new CGI::Session("driver:file", $sid);
    $s = new CGI::Session("driver:file", $sid, {Directory=>'/tmp'});


=head1 DESCRIPTION

When CGI::Session object is created without explicitly setting I<driver>, I<file> will be assumed.
I<file> - driver will store session data in plain files, where each session will be stored in a separate
file.

Naming conventions of session files are defined by C<$CGI::Session::Driver::file::FileName> global variable. 
Default value of this variable is I<cgisess_%s>, where %s will be replaced with respective session ID. Should
you wish to set your own FileName template, do so before requesting for session object:

    $CGI::Session::Driver::file::FileName = "%s.dat";
    $s = new CGI::Session();

=head2 DRIVER ARGUMENTS

The only optional argument for I<file> is B<Directory>, which denotes location of the directory where session ids are
to be kept. If B<Directory> is not set, defaults to whatever File::Spec->tmpdir() returns. So all the three lines
in the SYNOPSIS section of this manual produce the same result on a UNIX machine.

If specified B<Directory> does not exist, all necessary directory hierarchy will be created.

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut
