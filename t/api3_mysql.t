# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: api3_mysql.t,v 1.1.6.1 2003/07/26 13:37:36 sherzodr Exp $
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN { 

    # If you want to run MySQL tests, uncomment the following two
    # lines, create a table called "sessions" according to the
    # CGI::Session::MySQL table in the test database. 
    print "1..0\n";
    exit();

    # Check if DB_File is avaialble. Otherwise, skip this test
    eval 'require DBI';    
    if ( $@ ) {
        print "1..0\n";
        exit(0);
    }

    eval 'require DBD::mysql';
    if ( $@ ) {
        print "1..0\n";
        exit(0);
    }

    require Test;
    Test->import();
    
    plan(tests => 14); 
};


use CGI::Session;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my %options = (
    DataSource => "DBI:mysql:sherzodr_shop",
    User        => "sherzodr_shop",
    Password    => "marley01"
);

my $s = new CGI::Session("driver:MySQL", undef, \%options );

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

$s->flush();

my $s2 = new CGI::Session("driver:MySQL", $sid, \%options);
ok($s2);

ok($s2->id() eq $sid);

ok($s2->param('email'));
ok($s2->param('author'));
ok($s2->expire());


$s2->delete();


