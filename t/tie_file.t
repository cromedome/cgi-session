# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id$
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN {     
    require Test;
    Test->import();
    
    plan(tests => 8); 
};

use CGI::Session;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

ok(tie my %s, "CGI::Session", undef, undef, {Directory=>"t"});

#$s->trace(1, "t/trace.log");
    
ok($s{_SESSION_ID});

$s{author} = "Sherzod Ruzmetov";
$s{email}  = "sherzodr\@cpan.org";
tied(%s)->expire("+10h");

my $sid = $s{_SESSION_ID};

untie(%s);



ok(tie my %s2, "CGI::Session", "dr:File", $sid, {Directory=>"t"});

ok($s2{_SESSION_ID}, $sid);
ok($s2{author}, "Sherzod Ruzmetov");
ok($s2{email}, 'sherzodr@cpan.org');
ok($s2{_SESSION_ETIME});

tied(%s2)->delete();

untie(%s2);

