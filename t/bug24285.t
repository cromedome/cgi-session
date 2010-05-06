use strict;
use File::Path;
use File::Spec;
use Test::More ('no_plan');

BEGIN {
    use_ok('CGI::Session');
    use_ok("CGI::Session::Driver");
    use_ok("CGI::Session::Driver::file");
}

my($dir_name) = File::Spec->catdir('t', 'sessiondata');

my $opt_dsn;
my $id;
my $file_name;

{
    $opt_dsn = {Directory=>$dir_name};

    ok(my $s = CGI::Session->new('driver:file;serializer:default', undef, $opt_dsn), 'Created CGI::Session object successfully');

    $id        = $s -> id();
    $file_name = "t/sessiondata/cgisess_$id";
}

ok(-e $file_name, 'Created file outside /tmp successfully');

rmtree $dir_name;
