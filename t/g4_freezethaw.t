
use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

eval "require FreezeThaw";
if ( $@ ) {
    plan(skip_all=>"FreezeThaw is NOT available");
    exit(0);
}

my $t = CGI::Session::Test::Default->new(
    dsn => "Driver:file;serial:FreezeThaw",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

$t->run();
