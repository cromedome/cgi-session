# $Id$

use strict;
use diagnostics;

use Test::More qw/no_plan/;
use Env;

require CGI::Session;
CGI::Session->import;

my $session;
my $sessionid;

# Testing without ip_match
$ENV{REMOTE_ADDR}='127.0.0.1';
is($CGI::Session::IP_MATCH,0,'ip_match off by default');

ok($session=CGI::Session->new,'create new session');
$session->param('TEST','VALUE');
is($session->param('TEST'),'VALUE','check param TEST set');

ok($sessionid=$session->id,'store session id');
$ENV{REMOTE_ADDR}='127.0.0.2';

$session->flush;
ok($session=CGI::Session->new($sessionid),'load session with different IP');
is($session->id,$sessionid,'Same session id');
is($session->param('TEST'),'VALUE','TEST param still set');

$session->flush;
# Testing with ip_match set.
CGI::Session->import qw/-ip_match/;

is($CGI::Session::IP_MATCH,1,'ip_match switched on');

$session->flush;
ok($session=CGI::Session->new,'create new session');
ok($session->_ip_matches,'REMOTE_IP matches session');
$session->param('TEST','VALUE');
is($session->param('TEST'),'VALUE','check param TEST set');

ok($sessionid=$session->id,'store session id');

$session->flush;
ok($session=CGI::Session->new($sessionid),'new session - same ip');
is($session->id,$sessionid,'same session id');
ok($session->_ip_matches,'REMOTE_IP matches session');
is($session->param('TEST'),'VALUE','check param TEST set');

$session->flush;
$ENV{REMOTE_ADDR}='127.0.0.1';
ok($session=CGI::Session->new($sessionid),'new session - different ip');
isnt($session->id,$sessionid,'new session id');
