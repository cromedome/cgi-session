# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 4 };
use CGI::Session::DB_File;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $s = new CGI::Session::DB_File('c51a3cf001bc2d1973d7979decff4879', {Directory=>"t"});

ok($s);

ok($s->id);

$s->param(name=>'shrezodR');

ok($s->param('name'));

