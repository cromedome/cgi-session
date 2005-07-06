# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: file.t,v 1.5.4.1.2.1 2003/07/26 13:37:36 sherzodr Exp $
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN { 
    # Check if DB_File is avaialble. Otherwise, skip this test

    require Test;
    Test->import();
    
    plan(tests => 16); 
};
use CGI::Session::File;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.
$CGI::Session::File::FileName = 'cgisession_%s.txt';
my $s = new CGI::Session::File(undef, {Directory=>"t"} )
    or die $CGI::Session::errstr;

ok($s);
    
ok($s->id);

$s->param(author=>'Sherzod Ruzmetov', name => 'CGI::Session', version=>'1'   );

ok($s->param('author'));

ok($s->param('name'));

ok($s->param('version'));


$s->param(-name=>'email', -value=>'sherzodr@cpan.org');

ok($s->param(-name=>'email'));

ok(!$s->expires() );

$s->expires("+10m");

ok($s->expire());

my $sid = $s->id();

$s->flush();

my $s2 = new CGI::Session::File($sid, {Directory=>'t'});
ok($s2);

ok($s2->id() eq $sid);

ok($s2->param('email'));
ok($s2->param('author'));
ok($s2->expire());


$s2->clear('email');
ok($s2->param('email') ? 0 : 1);
ok($s2->param('author'));

$s2->delete();


