package CGI::Session::Driver::mysql;

use strict;
use CGI::Session::Driver::DBI;
use vars qw( $VERSION @ISA );


@ISA = qw( CGI::Session::Driver::DBI );
$VERSION = "2.01";
$CGI::Session::Driver::mysql::TABLE_NAME = "sessions";


sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;

    return $self->error("store(): usage error") unless $sid && $datastr;
    return $self->{Handle}->do("REPLACE INTO " . $self->{TableName} . " (id, a_session) VALUES(?, ?)", undef, $sid, $datastr);
}


sub table_name { $CGI::Session::Driver::mysql::TABLE_NAME }



1;


