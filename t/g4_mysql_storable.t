my %dsn = (
    DataSource  => $ENV{CGISESS_MYSQL_DSN}      || "dbi:mysql:test",
    User        => $ENV{CGISESS_MYSQL_USER}     || $ENV{USER},
    Password    => $ENV{CGISESS_MYSQL_PASSWORD} || undef,
    TableName   => 'sessions'
);


use strict;
use File::Spec;
use Test::More;
use CGI::Session::Test::Default;

for ( "DBI", "DBD::mysql", "Storable" ) {
    unless ( eval "require $_" ) {
        plan(skip_all=>"$_ is NOT available");
        exit(0);
    }
}

my $dbh = DBI->connect($dsn{DataSource}, $dsn{User}, $dsn{Password}, {RaiseError=>0, PrintError=>0});
unless ( $dbh ) {
    plan(skip_all=>"Couldn't establish connection with the server");
    exit(0);
}

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
    dsn => "dr:mysql;ser:Storable",
    args=>{Handle=>$dbh, TableName=>$dsn{TableName}});

$t->run();
