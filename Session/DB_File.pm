package CGI::Session::DB_File;

# $Id$

use strict;
use DB_File;
use Carp 'croak';
use base qw(CGI::Session);


sub retrieve {
    my ($self, $options, $id) = @_;

    my $directory = $options->[1]->{Directory}
                or croak "Directory option missing";

    tie (my %db, "DB_File", O_RDWR|O_CREAT, 0644, $DB_HASH) or die $!;





}

1;

