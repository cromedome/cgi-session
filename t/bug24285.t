use strict;
use Test::More ('no_plan');

BEGIN { 
    use_ok('CGI::Session');
    use_ok("CGI::Session::Driver");
    use_ok("CGI::Session::Driver::file");
}

my $opt_dsn;
my $id;
my $file_name;

{
    $opt_dsn = {Directory=>'./sessiondata'};

    ok(my $s = CGI::Session->new('driver:file;serializer:default', undef, $opt_dsn), 'Created CGI::Session object successfully');

    $id        = $s -> id();
    $file_name = "./sessiondata/cgisess_$id";
}

ok(-e $file_name, 'Created file outside /tmp successfully');
