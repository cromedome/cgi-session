package CGI::Session::File;

# $Id$

use File::Spec;
use Fcntl (':DEFAULT', ':flock');
use base qw(
    CGI::Session
    CGI::Session::Serialize::Storable
    CGI::Session::ID::MD5
);


sub store {
    my ($self, $sid, $options, $data) = @_;

    $self->File_init($sid, $options);
    sysopen (FH, $self->{_file_path}, O_WRONLY|O_CREAT, 0644) or die "Couldn't store $sid into $self->{_file_path}: $!";
    flock(FH, LOCK_EX) or die "Couldn't get LOCK_EX: $!";
    print FH $self->freeze($data);
    close(FH) or die "Couldn't close $self->{_file_path}: $!";

    return 1;
}




sub retrieve {
    my ($self, $sid, $options) = @_;

    $self->File_init($sid, $options);
    sysopen(FH, $self->{_file_path}, O_RDONLY) or return;
    flock(FH, LOCK_SH) or die "Couldn't lock the file: $!";
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

    return unlink ($self->{_file_path});
}





sub teardown {
    my ($self, $sid, $options) = @_;


}




sub File_init {
    my ($self, $sid, $options) = @_;

    my $dir = $options->[1]->{Directory};
    my $filename = sprintf("cgisess_%s", $sid);
    my $path = File::Spec->catfile($dir, $filename);    
    
    $self->{_file_path} = $path;

    
}








1;       