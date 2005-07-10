use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

eval { require FreezeThaw };
plan skip_all=>"FreezeThaw is NOT available" if $@;

my $t = CGI::Session::Test::Default->new(
    dsn => "Driver:file;serial:FreezeThaw",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

plan tests => $t->number_of_tests;
$t->run();
