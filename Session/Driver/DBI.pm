package CGI::Session::Driver::DBI;

use strict;
use diagnostics;

use CGI::Session::Driver;
use DBI;
use vars qw( $VERSION @ISA );

@ISA = qw( CGI::Session::Driver );
$VERSION = "2.01";


sub init {
    my $self = shift;
    unless ( defined $self->{Handle} ) {
        $self->{Handle} = DBI->connect( 
            $self->{DataSource}, $self->{User}, $self->{Password}, 
            { RaiseError=>1, PrintError=>1, AutoCommit=>1 }
        );
        $self->{_disconnect} = 1;
    }
    $self->{TableName} ||= $self->table_name || "sessions";
}

sub table_name {    return "sessions"   }


sub retrieve {
    my $self = shift;
    my ($sid) = @_;

    return $self->error("retrieve(): usage error") unless $sid;
    return $self->{Handle}->selectrow_array("SELECT a_session FROM " . $self->{TableName} . " WHERE id=?", undef, $sid);
}


sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;

    return $self->error("store(): usage error") unless $sid && $datastr;
    my $count = $self->{Handle}->selectrow_array("SELECT COUNT(*) FROM " . $self->{TableName} . " WHERE id=?", undef, $sid);
    if ( $count ) {
        return $self->{Handle}->do("UPDATE " . $self->{TableName} . " SET a_session=? WHERE id=?", undef, $datastr, $sid);
    }
    return $self->{Handle}->do("INSERT INTO " . $self->{TableName} . " (id, a_session) VALUES(?, ?)", undef, $sid, $datastr);
}


sub remove {
    my $self = shift;
    my ($sid) = @_;

    return $self->error("remove(): usage error") unless $sid;

    return $self->{Handle}->do("DELETE FROM " . $self->{TableName} . " WHERE id=?", undef, $sid);
}


sub DESTROY {
    my $self = shift;

    if ( $self->{_disconnect} ) {
        $self->{Handle}->disconnect();
    }
}






1;

