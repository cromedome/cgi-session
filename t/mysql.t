# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id$
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 11  };
use CGI::Session::MySQL;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my %options = (
    DataSource => "DBI:mysql:sherzodr_shop",
    User        => "sherzodr_shop",
    Password    => "marley01"
);

my $s = new CGI::Session::MySQL(undef, \%options) 
    or die $CGI::Session::errstr;

ok($s);
    
ok($s->id);

$s->param(author=>'Sherzod Ruzmetov', name => 'CGI::Session', version=>'1'   );

ok($s->param('author'));

ok($s->param('name'));

ok($s->param('version'));


$s->param(-name=>'email', -value=>'sherzodr@cpan.org');

ok($s->param(-name=>'email'));

ok(!$s->expire() );

$s->expire("+10m");

ok($s->expire());

my $sid = $s->id();

$s->close();

my $s2 = new CGI::Session::MySQL($sid, \%options);
ok($s2);

ok($s2->id() eq $sid);

$s2->delete();


