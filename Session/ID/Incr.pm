package CGI::Session::ID::Incr;

use File::Spec;
use Fcntl (':DEFAULT', ':flock');


sub generate_id {
    my ($self, $options) = @_;

    my $IDFile = $options->[1]->{IDFile} or croak "Don't know where to store the id";
    my $IDIncr = $options->[1]->{IDIncr} || 1;
    my $IDInit = $options->[1]->{IDInit} || 0;
    
    unless (sysopen(FH, $IDFile, O_RDWR|O_CREAT, 0644) ) {
        $self->error("Couldn't open IDFile=>$IDFile: $!");
        return undef;
    }
    unless (flock(FH, LOCK_EX) ) {
        $self->error("Couldn't lock IDFile=>$IDFile: $!");
        return undef;
    }
    my $ID = <FH> || $IDInit;
    unless ( seek(FH, 0, 0) ) {
        $self->error("Couldn't seek IDFile=>$IDFile: $!");
        return undef;
    }
    unless ( truncate(FH, 0) ) {
        $self->error("Couldn't trunated IDFile=>$IDFile: $!");
        return undef;
    }
    print FH $ID+$IDIncr;
    unless ( close(FH) ) {
        $self->error("Couldn't close IDFile=>$IDFile: $!");
        return undef;
    }

    return 1;
} 







1;
