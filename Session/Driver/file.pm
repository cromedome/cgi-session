package CGI::Session::Driver::file;

use strict;
use diagnostics;

use File::Spec;
use Fcntl qw(:DEFAULT :flock);
use CGI::Session::Driver;
use vars qw( @ISA $VERSION $NAME);

@ISA        = qw( CGI::Session::Driver );
$VERSION    = "2.00";
$NAME       = "cgisess_%s";


sub init {
    my $self = shift;
    $self->{Directory} ||= File::Spec->tmpdir();

    unless ( -d $self->{Directory} ) {
        require File::Path;
        unless ( File::Path::mkpath($self->{Directory}) ) {
            return $self->error( "init(): couldn't create directory path: $!" );
        }
    }
}




sub retrieve {
    my $self = shift;
    my ($sid) = @_;

    my $directory   = $self->{Directory};
    my $file        = sprintf( $NAME, $sid );
    my $path        = File::Spec->catfile($directory, $file);

    return 0 unless -e $path;

    unless ( sysopen(FH, $path, O_RDONLY) ) {
        return $self->error( "retrieve(): couldn't open '$path': $!" );
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
    my $file      = sprintf( $NAME, $sid );
    my $path      = File::Spec->catfile($directory, $file);
    sysopen(FH, $path, O_WRONLY|O_CREAT|O_TRUNC) or return $self->error( "store(): couldn't open '$path': $!" );
    flock(FH, LOCK_EX) or return $self->error( "store(): couldn't lock '$path': $!" );
    print FH $datastr;
    close(FH) or return $self->error( "store(): couldn't close '$path': $!" );
    return 1;
}


sub remove {
    my $self = shift;
    my ($sid) = @_;

    my $directory = $self->{Directory};
    my $file      = sprintf( $NAME, $sid );
    my $path      = File::Spec->catfile($directory, $file);
    unlink($path) or return $self->error( "remove(): couldn't unlink '$path': $!" );
}





sub DESTROY {
    my $self = shift;

}














1;
