package CGI::Session::FileX;

# $Id$

use strict;
use Carp;
use File::Spec;
use Fcntl qw/:DEFAULT :flock/;
use base qw(
    CGI::Session
    CGI::Session::ID::MD5
    CGI::Session::Serialize::Default
);


# Load neccessary libraries below

use vars qw($VERSION);

$VERSION = '0.1';


sub filex_init {
    my ($self, $sid, $options) = @_;

    if ( defined $self->cache('_FH') ) {
        return $self->cache('_FH');
    }
    
    my $dir = $options->[1]->{Directory} || $options->[1]->{Dir};
    unless ( $dir ) {
        croak "Directory driver option is missing";
    }
    my $filename = $options->[1]->{FileName} || 'cgisess_%s';
    $filename    = File::Spec->catfile($dir, sprintf($filename, $sid));

    sysopen(FH, $filename, O_RDWR|O_CREAT, 0600) or die $!;

    $self->cache(
        _FH     => \*FH,
        _FILE   => $filename
    );

    return $self->filex_init($sid, $options);
}

sub store {
    my ($self, $sid, $options, $data) = @_;

    my $fh = $self->filex_init($sid, $options);
    unless(flock($fh, LOCK_EX) ) {
        croak "Couldn't lock the file: $!";
    }
    
    unless(truncate($fh, 0) ) {
        croak "Couldn't truncate the file: $!";
    }

    unless(seek($fh, 0, 0) ) {
        croak "Couldn't seek to the beginning of the file: $!";
    }

    print $fh $self->freeze($data);    

    unless(flock($fh, LOCK_UN) ) {
        croak "Couldn't release the lock: $!";
    }

    return 1;
}


sub retrieve {
    my ($self, $sid, $options) = @_;

    # you will need to retrieve the stored data, and 
    # deserialize it using $self->thaw() method
    my $fh = $self->filex_init($sid, $options);

    unless(flock($fh, LOCK_SH) ) {
        croak "Couldn't get lock on the file: $!";
    }

    unless(seek($fh, 0, 0) ) {
        croak "Couldn't seek to the beginning of the file: $!";
    }

    my $datastr = "";
    while ( <$fh> ) {
        $datastr = $_;
    }
    unless(flock($fh, LOCK_UN) ) {
        croak "Couldn't unlock the file: $!";
    }

    return $self->thaw($datastr);
}



sub remove {
    my ($self, $sid, $options) = @_;

    # you simply need to remove the data associated 
    # with the id

    my $file = $self->cache('_FILE') or die "No '_FILE' exists";
    unless(unlink($file)) {
        croak "couldn't delete '$file': $!";
    }
    return 1;    
}



sub teardown {
    my ($self, $sid, $options) = @_;

    # this is called just before session object is destroyed
    my $fh = $self->cache('_FH');
    if ( defined $fh ) {
        CORE::close($fh) or croak "Couldn't close $fh: $!";
    }

    return 1;
}




# $Id$

1;       

=pod

=head1 NAME

CGI::Session::BluePrint - Default CGI::Session driver BluePrint

=head1 SYNOPSIS
    
    use CGI::Session::BluePrint
    $session = new CGI::Session("driver:BluePrint", undef, {...});

For more examples, consult L<CGI::Session> manual

=head1 DESCRIPTION

CGI::Session::BluePrint is a CGI::Session driver.
To write your own drivers for B<CGI::Session> refere L<CGI::Session> manual.

=head1 COPYRIGHT

Copyright (C) 2002 Your Name. All rights reserved.

This library is free software and can be modified and distributed under the same
terms as Perl itself. 

=head1 AUTHOR

Your name

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session|CGI::Session> - CGI::Session manual

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut


# $Id$
