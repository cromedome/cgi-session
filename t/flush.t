use File::Spec;
use Test::More qw/no_plan/;
use strict;

use CGI::Session;
my $dir = File::Spec->catdir('t', 'sessiondata');
my $id;
{
    my $ses = CGI::Session->new(undef,undef,{Directory=> $dir });
    $id = $ses->id();
    ok($id, "found session id");
}

ok(-r "$dir/cgisess_".$id, "found session data file");
