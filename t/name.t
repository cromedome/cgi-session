#/usr/bin/perl -w

use strict;
use diagnostics;

use Test::More tests => 10;
use_ok('CGI::Session');

my $session = CGI::Session->new('id:static','testname',{Directory=>'t'});
ok($session);

# as class method
ok(CGI::Session->name,'name used as class method');

ok(CGI::Session->name('fluffy'),'name as class method w/ param'); 
ok(CGI::Session->name eq 'fluffy','name as class method w/ param effective?'); 

# as instance method
ok($session->name,'name as instance method');
ok($session->name eq CGI::Session->name,'instance method falls through to class');

ok($session->name('spot'),'instance method w/ param');

ok($session->name eq 'spot','instance method w/ param effective?');

ok(CGI::Session->name eq 'fluffy','instance method did not affect class method');