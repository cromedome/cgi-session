# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 6 };
use CGI::Session;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $session = new CGI::Session("id:Static", 'static', {Directory=>"t"});

ok($session);

$session->param(
    fname=>"Sherzod", 
    lname => "Ruzmetov",
    email => 'sherzodr@cpan.org',
    web   => 'http://author.ultracgis.com' );

ok($session->id(), 'static');

undef($session);

my $session1 = new CGI::Session("id:Static", 'static', {Directory=>'t'});
ok($session1);


ok($session1->param('fname'), 'Sherzod');
ok($session1->param('email'), 'sherzodr@cpan.org');


