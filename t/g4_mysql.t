my %dsn;
if (defined $ENV{DBI_DSN} && ($ENV{DBI_DSN} =~ m/^dbi:mysql:/)) {
    %dsn = (
        DataSource  => $ENV{DBI_DSN},
        Password    => $ENV{CGISESS_MYSQL_PASSWORD} || undef,
        TableName   => 'sessions'
    );
}
else {
    %dsn = (
        DataSource  => $ENV{CGISESS_MYSQL_DSN},
        User        => $ENV{CGISESS_MYSQL_USER}     || $ENV{USER},
        Password    => $ENV{CGISESS_MYSQL_PASSWORD} || undef,
        Socket      => $ENV{CGISESS_MYSQL_SOCKET}   || undef,
        TableName   => 'sessions'
    );
}


use strict;
use File::Spec;
use Test::More;
use CGI::Session::Test::Default;

for (qw/DBI DBD::mysql/) {
    eval "require $_";
    if ( $@ ) {
        plan(skip_all=>"$_ is NOT available");
        exit(0);
    }
}



require CGI::Session::Driver::mysql;
my $dsnstring = CGI::Session::Driver::mysql->_mk_dsnstr(\%dsn);

my $dbh = DBI->connect($dsnstring, $dsn{User}, $dsn{Password}, {RaiseError=>0, PrintError=>1});
unless ( $dbh ) {
    plan(skip_all=>"Couldn't establish connection with the MySQL server: " . DBI->errstr);
    exit(0);
}

my $count;
eval { ($count) = $dbh->selectrow_array("SELECT COUNT(*) FROM $dsn{TableName}") };
unless ( defined $count ) {
    unless( $dbh->do(qq|
        CREATE TABLE $dsn{TableName} (
            id CHAR(32) NOT NULL PRIMARY KEY,
            a_session TEXT NULL
        )|) ) {
        plan(skip_all=>"Couldn't create $dsn{TableName}: " . $dbh->errstr);
        exit(0);
    }
}


my $t = CGI::Session::Test::Default->new(
    dsn => "dr:mysql",
    args=>{Handle=>$dbh, TableName=>$dsn{TableName}});


plan tests => $t->number_of_tests + 2;
$t->run();

{
    # This was documented to work in 3.95 and should be supported for compatibility
    my $obj;
    eval {
        # test.sessions will refer to the same 'sessions' table but is a unique name to test with
        $CGI::Session::MySQL::TABLE_NAME = 'test.sessions';
        my $avoid_warning = $CGI::Session::MySQL::TABLE_NAME;
        require CGI::Session::Driver::mysql;
        $obj = CGI::Session::Driver::mysql->new( {Handle=>$dbh} );
    };
    is($@,'', 'survived eval');
    is($obj->table_name, 'test.sessions', "setting table name through CGI::Session::MySQL::TABLE_NAME works");
}




