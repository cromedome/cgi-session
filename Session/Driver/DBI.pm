package CGI::Session::Driver::DBI;

use strict;
use diagnostics;

use DBI;
use Carp;
use CGI::Session::Driver;
use vars qw( $VERSION @ISA );

@ISA = qw( CGI::Session::Driver );
$VERSION = "2.01";


sub init {
    my $self = shift;
    unless ( defined $self->{Handle} ) {
        $self->{Handle} = DBI->connect( 
            $self->{DataSource}, $self->{User}, $self->{Password}, 
            { RaiseError=>0, PrintError=>0, AutoCommit=>1 }
        );
        unless ( $self->{Handle} ) {
            return $self->set_error( "init(): couldn't connect to database: " . DBI->errstr );
        }
        $self->{_disconnect} = 1;
    }
    $self->{TableName} ||= $self->table_name || "sessions";
}

sub table_name {
    my $class = shift;
    $class = ref( $class ) || $class;

    no strict 'refs';
    if ( @_ ) {
        ${ $class . "::TABLE_NAME" } = $_[0];
    }
    return ${ $class . "::TABLE_NAME" };
}


sub retrieve {
    my $self = shift;
    my ($sid) = @_;
    croak "retrieve(): usage error" unless $sid;

    my $dbh = $self->{Handle};
    my $sth = $dbh->prepare("SELECT a_session FROM " . $self->{TableName} . " WHERE id=?");
    unless ( $sth ) {
        return $self->set_error( "retrieve(): DBI->prepare failed with error message " . $dbh->errstr );
    }
    $sth->execute( $sid ) or return $self->set_error( "retrieve(): \$sth->execute failed with error message " . $dbh->errstr);

    my ($row) = $sth->fetchrow_array();
    return 0 unless $row;
    return $row;
}


sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my $dbh = $self->{Handle};
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM " . $self->{TableName} . " WHERE id=?");
    unless ( defined $sth ) {
        return $self->set_error( "store(): \$sth->prepare failed with message " . $dbh->errstr );
    }

    $sth->execute( $sid ) or return $self->set_error( "store(): \$sth->execute failed with message " . $dbh->errstr );
    if ( $sth->fetchrow_array ) {
        $dbh->do("UPDATE " . $self->{TableName} . " SET a_session=? WHERE id=?", undef, $datastr, $sid)
            or return $self->set_error( "store(): \$dbh->do failed " . $dbh->errstr );
    } else {
        $dbh->do("INSERT INTO " . $self->{TableName} . " (id, a_session) VALUES(?, ?)", undef, $sid, $datastr) 
            or return $self->set_error( "store(): \$dbh->do failed " . $dbh->errstr );
    }
    return 1;
}


sub remove {
    my $self = shift;
    my ($sid) = @_;
    croak "remove(): usage error" unless $sid;

    my $dbh = $self->{Handle};
    $dbh->do("DELETE FROM " . $self->{TableName} . " WHERE id=?", undef, $sid) 
        or return $self->set_error( "remove(): \$dbh->do failed " . $dbh->errstr );
    return 1;
}


sub DESTROY {
    my $self = shift;

    if ( $self->{_disconnect} ) {
        $self->{Handle}->disconnect();
    }
}


1;

=pod

=head1 NAME

CGI::Session::Driver::DBI - Base class for native DBI-related CGI::Session drivers

=head1 SYNOPSIS

    require CGI::Session::Driver::DBI;
    @ISA = qw( CGI::Session::Driver::DBI );

=head1 DESCRIPTION

In most cases you can create a new DBI-driven CGI::Session driver by simply creating an empty driver file
that inherits from CGI::Session::Driver::DBI. That's exactly what L<sqlite|CGI::Session::Driver::sqlite> does.
The only reason why this class doesn't suit for a valid driver is its name isn't in lowercase. I'm serious!

=head2 NOTES

CGI::Session::Driver::DBI defines init() method, which makes DBI handle available for drivers in 'Handle' attribute regardless
of what \%dsn_args were used in creating CGI::Session. Should your driver require non-standard initialization you have to
re-define init() method in your F<.pm> file, but make sure to set 'Handle' - object attribute to database handle (returned
by DBI->connect(...)) if you wish to inherit any of the methods from CGI::Session::Driver::DBI.

=head1 LICENSING

For support and licensing information see L<CGI::Session|CGI::Session>

=cut

