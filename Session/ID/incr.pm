package CGI::Session::ID::incr;

# $Id$

use strict;
#use diagnostics;

use File::Spec;
use Carp "croak";
use CGI::Session::ErrorHandler;
use Fcntl qw( :DEFAULT :flock );

@CGI::Session::ID::incr::ISA     = qw( CGI::Session::ErrorHandler );
$CGI::Session::ID::incr::VERSION = '1.4';

sub generate_id {
    my ($self, $args) = @_;

    my $IDFile = $args->{IDFile} or croak "Don't know where to store the id";
    my $IDIncr = $args->{IDIncr} || 1;
    my $IDInit = $args->{IDInit} || 0;

    sysopen(FH, $IDFile, O_RDWR|O_CREAT, 0666) or return $self->set_error("Couldn't open IDFile=>$IDFile: $!");
    flock(FH, LOCK_EX) or return $self->set_error("Couldn't lock IDFile=>$IDFile: $!");
    my $ID = <FH> || $IDInit;
    seek(FH, 0, 0) or return $self->set_error("Couldn't seek IDFile=>$IDFile: $!");
    truncate(FH, 0) or return $self->set_error("Couldn't trunated IDFile=>$IDFile: $!");
    $ID += $IDIncr;
    print FH $ID;
    close(FH) or return $self->set_error("Couldn't close IDFile=>$IDFile: $!");
    return $ID;
}


1;

__END__;

=pod

=head1 NAME

CGI::Session::ID::incr - CGI::Session ID driver

=head1 SYNOPSIS

    use CGI::Session qw/-api3/;

    $session = new CGI::Session("id:Incr", undef,
                            {   Directory   => '/tmp',
                                IDFile      => '/tmp/cgisession.id',
                                IDInit      => 1000,
                                IDIncr      => 2 });

=head1 DESCRIPTION

CGI::Session::ID::incr is to generate auto incrementing Session IDs. Compare it with CGI::Session::ID::MD5, where session 
ids are truely random 32 character long strings. CGI::Session::ID::Incr expects the following arguments passed to CGI::Session->new() as the third argument

=over 4

=item IDFile

Location where auto incremened IDs are stored. This attribute is required.

=item IDInit

Initial value of the ID if it's the first ID to be generated. For example, if you want the ID numbers to start with 1000 as opposed to 0, that's where you should set your value. Default is 0.

=item IDIncr

How many digits each number should increment by. For example, if you want the first generated id to start with 1000, and each subsequent id to increment by 10, set I<IDIncr> to 10 and I<IDInit> to 1000 Default is 1.

=back

=head1 LICENSING

For support and licensing information see L<CGI::Session|CGI::Session>

=cut
