
use File::Spec;
use CGI::Session::Test::Default;

unless ( eval "require DB_File" ) {
    plan(skip_all=>"DB_File is NOT available");
    exit(0);
}

my $t = CGI::Session::Test::Default->new(
    dsn => "driver:DB_File",
    args=>{FileName => File::Spec->catfile('t', 'sessiondata', 'cgisess.db')});

$t->run();
