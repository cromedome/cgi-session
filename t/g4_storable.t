
use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

eval "require Storable";
if ( $@ ) {
    plan(skip_all=>"Storable is NOT available");
    exit(0);
}

my $t = CGI::Session::Test::Default->new(
    dsn => "serializer:Storable",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

$t->run();
