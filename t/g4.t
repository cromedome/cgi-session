
use File::Spec;
use CGI::Session::Test::Default;

my $t = CGI::Session::Test::Default->new(
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

$t->run();
