package CGI::Session::DB_File;

# $sid: DB_File.pm,v 1.2 2002/11/03 08:27:04 sherzodr Exp $

use strict;
use warnings;
use DB_File;
use File::Spec;
use Carp 'croak';
use base qw(
        CGI::Session
        CGI::Session::Serialize::Storable 
        CGI::Session::ID::MD5);

use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;


sub retrieve {
    my ($self, $sid, $options) = @_;
    
    my $db = $self->DB_File_init($options);
    
    if ( defined $db->{$sid} ) {
        return $self->thaw($db->{$sid});
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
    return $db->{$sid};
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
    my $file= $options->[1]->{FileName} || 'cgisession.db';
    my $path= File::Spec->catfile($dir, $file);

    tie (my %db, "DB_File", $path, O_RDWR|O_CREAT, 0664, $DB_HASH) or die $!;

    $self->{_db_file_hash} = \%db;
    $self->{_db_file_path} = $path;

    return $self->{_db_file_hash};
}



1;

