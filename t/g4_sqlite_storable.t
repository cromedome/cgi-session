
use strict;
use File::Spec;
use Test::More;
use CGI::Session::Test::Default;

for ( "DBI", "DBD::SQLite", "Storable" ) {
    eval "require $_";
    if ( $@ ) {
        plan(skip_all=>"$_ is NOT available");
        exit(0);
    }
}

my %dsn = (
    DataSource  => "dbi:SQLite:dbname=" . File::Spec->catfile('t', 'sessiondata', 'sessions.sqlt'),
    TableName   => 'sessions'
);

my $dbh = DBI->connect($dsn{DataSource}, '', '', {RaiseError=>0, PrintError=>0});
unless ( $dbh ) {
    plan(skip_all=>"Couldn't establish connection with the server");
    exit(0);
}
$dbh->{sqlite_handle_binary_nulls} = 1;

my ($count) = $dbh->selectrow_array("SELECT COUNT(*) FROM $dsn{TableName}");
unless ( defined $count ) {
    unless( $dbh->do(qq|
        CREATE TABLE $dsn{TableName} (
            id CHAR(32) NOT NULL PRIMARY KEY,
            a_session TEXT NULL
        )|) ) {
        plan(skip_all=>$dbh->errstr);
        exit(0);
    }
}


my $t = CGI::Session::Test::Default->new(
    dsn => "driver:sqlite;seRializer:storable",
    args=>{Handle=>$dbh, TableName=>$dsn{TableName}});
    #args => \%dsn);

$t->run();
