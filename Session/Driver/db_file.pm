package CGI::Session::Driver::db_file;

use strict;
use diagnostics;

use Carp;
use DB_File;
use File::Spec;
use File::Basename;
use CGI::Session::Driver;
use Fcntl qw( :DEFAULT :flock );
use vars qw( $VERSION @ISA );

@ISA = qw( CGI::Session::Driver );
$CGI::Session::Driver::db_file::FILE_NAME = "cgisess.db";


sub init {
    my $self = shift;

    $self->{FileName}  ||= $CGI::Session::Driver::db_file::FILE_NAME;
    unless ( $self->{Directory} ) {
        $self->{Directory} = dirname( $self->{FileName} );
        $self->{FileName}  = basename( $self->{FileName} );
    }
    unless ( -d $self->{Directory} ) {
        require File::Path;
        File::Path::mkpath($self->{Directory}) or return $self->set_error("init(): couldn't mkpath: $!");
    }
    return 1;
}


sub retrieve {
    my $self = shift;
    my ($sid) = @_;
    croak "retrieve(): usage error" unless $sid;

    my ($dbhash, $unlock) = $self->_tie_db_file(O_RDONLY) or return;
    my $datastr =  $dbhash->{$sid};
    untie(%$dbhash);
    $unlock->();
    return $datastr || 0;
}


sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my ($dbhash, $unlock) = $self->_tie_db_file(O_RDWR|O_CREAT, LOCK_EX) or return;
    $dbhash->{$sid} = $datastr;
    untie(%$dbhash);
    $unlock->();
    return 1;
}



sub remove {
    my $self = shift;
    my ($sid) = @_;
    croak "remove(): usage error" unless $sid;

    my ($dbhash, $unlock) = $self->_tie_db_file(O_RDWR, LOCK_EX) or return;
    delete $dbhash->{$sid};
    untie(%$dbhash);
    $unlock->();
    return 1;
}


sub DESTROY {}


sub _lock {
    my $self = shift;
    my ($db_file, $lock_type) = @_;

    croak "_lock(): usage error" unless $db_file;
    $lock_type ||= LOCK_SH;

    my $lock_file = $db_file . '.lck';
    sysopen(LOCKFH, $lock_file, O_RDWR|O_CREAT) or die "couldn't create lock file '$lock_file': $!";
    flock(LOCKFH, $lock_type)                   or die "couldn't lock '$lock_file': $!";
    return sub {
        close(LOCKFH) && unlink($lock_file);
        1;
    };
}



sub _tie_db_file {
    my $self                 = shift;
    my ($o_mode, $lock_type) = @_;
    $o_mode     ||= O_RDWR|O_CREAT;

    my $db_file     = File::Spec->catfile( $self->{Directory}, $self->{FileName} );
    my $unlock = $self->_lock($db_file, $lock_type);
    my %db;
    unless( tie %db, "DB_File", $db_file, $o_mode, 0666 ){
        $unlock->();
        return $self->set_error("_tie_db_file(): couldn't tie '$db_file': $!");
    }
    return (\%db, $unlock);
}

1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::db_file - CGI::Session driver for BerkeleyDB using DB_File

=head1 SYNOPSIS

    $s = new CGI::Session("driver:db_file", $sid);
    $s = new CGI::Session("driver:db_file", $sid, {FileName=>'/tmp/cgisessions.db'});

=head1 DESCRIPTION

B<db_file> stores session data in BerkelyDB file using DB_File - Perl module.
All sessions will be stored in a single file, specified in I<FileName> driver argument as
in the above example. If I<FileName> isn't given, defaults to F</tmp/cgisess.db>, or its
equivalent on a non-UNIX machine.

If directory hierarchy leading to the file does not exist, will be created for you.

=head1 LICENSING

For support and licensing information see L<CGI::Session|CGI::Session>

=cut

