
use File::Spec;
use CGI::Session::Test::Default;

unless ( eval "require Storable" ) {
    plan(skip_all=>"Storable is NOT available");
    exit(0);
}

my $t = CGI::Session::Test::Default->new(
    dsn => "serializer:Storable",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

$t->run();
