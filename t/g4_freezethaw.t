
use File::Spec;
use CGI::Session::Test::Default;

unless ( eval "require FreezeThaw" ) {
    plan(skip_all=>"FreezeThaw is NOT available");
    exit(0);
}

my $t = CGI::Session::Test::Default->new(
    dsn => "serial:FreezeThaw",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

$t->run();
