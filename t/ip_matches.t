use strict;
use diagnostics;

use File::Spec;
use Test::More qw/no_plan/;
use Env;

require CGI::Session;
CGI::Session->import;

my $save_id_1;
my $save_id_2;
my $save_id_3;

{
my $session;
my $sessionid;

# Testing without ip_match.

$ENV{REMOTE_ADDR}='127.0.0.1';
is($CGI::Session::IP_MATCH,0,'ip_match off by default');

# Create 1st session, with 1st IP address. Get 1st id.

ok($session=CGI::Session->new,'create new session');
$save_id_1 = $session->id;

diag "\n1st id (new): $save_id_1 / $ENV{REMOTE_ADDR}";

# Save a value.

$session->param('TEST','VALUE');
$session->flush;

is($session->param('TEST'),'VALUE','check param TEST set');

ok($sessionid=$session->id,'store session id');

# Create 2nd session, with 1st id but 2nd IP address.

$ENV{REMOTE_ADDR}='127.0.0.2';
ok($session=CGI::Session->new($sessionid),'load session with different IP');
$session->flush;

diag "2nd id (should match 1st): " . $session->id . " / $ENV{REMOTE_ADDR}";

is($session->id,$sessionid,'Same session id');
is($session->param('TEST'),'VALUE','TEST param still set');

# Test with ip_match set.

CGI::Session->import qw/-ip_match/;

is($CGI::Session::IP_MATCH,1,'ip_match switched on');

# Create 3rd session, with 2nd IP address. Get 2nd id.

ok($session=CGI::Session->new,'create new session');
$save_id_2 = $session->id;

diag "3rd id (new): " . $session->id . " / $ENV{REMOTE_ADDR}";

ok($session->_ip_matches,'REMOTE_IP matches session');

# Save a value.

$session->param('TEST','VALUE');
$session->flush;

is($session->param('TEST'),'VALUE','check param TEST set');

ok($sessionid=$session->id,'store session id');

# Create 4th session, with 3rd id and 2nd IP address.

ok($session=CGI::Session->new($sessionid),'new session - same ip');
$session->flush;

diag "4th id (should match 3rd): " . $session->id . " / $ENV{REMOTE_ADDR}";

is($session->id,$sessionid,'same session id');
ok($session->_ip_matches,'REMOTE_IP matches session');
is($session->param('TEST'),'VALUE','check param TEST set');

# Revert to 1st IP address.

$ENV{REMOTE_ADDR}='127.0.0.1';

# Create 5th session, with 3rd id but 1st IP address.

ok($session=CGI::Session->new($sessionid),'new session - different ip');
$session->flush;
$save_id_3 = $session->id;

diag "5th id (new): $save_id_3 / $ENV{REMOTE_ADDR}";

isnt($session->id,$sessionid,'new session id');
}

# Emulate CGI::Session::Driver::file.pm.

my $dir_name = File::Spec->tmpdir();

unlink File::Spec->catfile($dir_name, "cgisess_$save_id_1");
unlink File::Spec->catfile($dir_name, "cgisess_$save_id_2");
unlink File::Spec->catfile($dir_name, "cgisess_$save_id_3");
