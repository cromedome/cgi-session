package CGI::Session::Driver::mysql;

use strict;
use diagnostics;

use Carp;
use CGI::Session::Driver::DBI;
use vars qw( $VERSION @ISA $TABLE_NAME );


@ISA = qw( CGI::Session::Driver::DBI );
$VERSION = "2.01";
$TABLE_NAME = "sessions";

sub init {
    my $self = shift;
    if ( $self->{DataSource} && ($self->{DataSource} !~ /^dbi:mysql/i) ) {
        $self->{DataSource} = "dbi:mysql:database=" . $self->{DataSource};
    }
    return $self->SUPER::init();
}

sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my $dbh = $self->{Handle};
    $dbh->do("REPLACE INTO " . $self->{TableName} . " (id, a_session) VALUES(?, ?)", undef, $sid, $datastr)
        or return $self->set_error( "store(): \$dbh->do failed " . $dbh->errstr );
    return 1;
}

1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::mysql - CGI::Session driver for MySQL database

=head1 SYNOPSIS

    $s = new CGI::Session( "driver:mysql", $sid);
    $s = new CGI::Session( "driver:mysql", $sid, {
                                                DataSource  => 'dbi:mysql:test',
                                                User        => 'sherzodr',
                                                Password    => 'hello'
                          });
    $s = new CGI::Session( "driver:mysql", $sid, { Handle => $dbh } );

=head1 DESCRIPTION

B<mysql> stores session records in a MySQL table, where session will be stored
in a separate table row. Name of the sessions table defaults to I<sessions>. This can be
changed by setting C<$CGI::Session::Driver::mysql::TABLE_NAME> to desired value or setting
I<TableName> dsn argument while creating session object:

    $s = new CGI::Session("driver:mysql", $sid, {Handle=>$dbh, TableName=>$tblname});

=head2 DRIVER ARGUMENTS

B<mysql> driver supports following attributes:

=over 4

=item DataSource

First argument to be passed to L<DBI|DBI>->connect(). If I<DataSource> string does not being
with I<dbi::mysql>, it will be prepended for you. This means instead of setting I<DataSource> to
I<dbi:mysql:test> you can safely set it to I<test> and I<dbi:mysql:test> will be assumed.

=item User

User privileged to connect to the database defined in I<DataSource>.

=item Password

Password of the I<User> privileged to connect to the database defined in I<DataSource>

=item Handle

To set existing database handle object ($dbh) returned by DBI->connect(). I<Handle> will override all the
above arguments, if any present.

=back

=head1 STORAGE COLUMNS

B<mysql> driver will expect storage table to have two columns, I<id CHAR(32) NOT NULL PRIMARY KEY>
and I<a_session TEXT NOT NULL>. <id> holds session id, and I<a_session> keeps serialized data. Table may keep other colulmns,
if you wish, but the driver will use only the above two.

Following command will create the sessions table:

    CREATE TABLE sessions (
        id CHAR(32) NOT NULL PRIMARY KEY,
        a_session TEXT NOT NULL
    );

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>.

=cut

