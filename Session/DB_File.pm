package CGI::Session::DB_File;

# $Id$

use strict;
use DB_File;
use File::Spec;
use Carp 'croak';
use base qw(CGI::Session 
        CGI::Session::Serialize::Storable 
        CGI::Session::ID::MD5);


sub retrieve {
    my ($self, $id, $options) = @_;

    die "retrieve...";
    my $directory = $options->[1]->{Directory}
                or croak "Directory option missing";
    
    my $file      = $options->[1]->{FileName} || 'cgisession.db';
    
    my $filename = File::Spec->catfile($directory, $file);

    tie (my %db, "DB_File", $filename, O_RDWR, 0644, $DB_HASH) or die $!;

    my $data = undef;
    if ( exists $db{$id} ) {
        return $self->thaw( $db{$id} );

    } else {
        return undef;
    }

}


sub store {
    my ($self, $id, $data, $options) = @_;

    my $directory = $options->[1]->{Directory}
                or croak "Directory option missing";
    
    my $file      = $options->[1]->{FileName} || 'cgisession.db';
    
    my $filename = File::Spec->catfile($directory, $file);

    tie (my %db, "DB_File", $filename, O_RDWR|O_CREAT, 0644, $DB_HASH) or die $!;
    $db{$id} = $self->freeze($data);
    untie (%db);

    return 1;
}






    



1;

