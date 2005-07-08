# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: api3_mysql.t,v 1.1.6.1 2003/07/26 13:37:36 sherzodr Exp $
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN { 
    use Test::More;

    # If you want to run MySQL tests, uncomment the following line,
    # create a table called "sessions" in the test database according to the
    # CGI::Session::MySQL docs.
    plan skip_all => 'MySQL needs to be manually set up. See this file for details';

    # Check if DB_File is avaialble. Otherwise, skip this test
    eval { require DBI };    
    if ( $@ ) {
        plan skip_all => "DBI not available";
    }

    eval { require DBD::mysql };
    if ( $@ ) {
        plan skip_all => 'DBD::mysql not available';
    }

    plan(tests => 14); 
    use_ok('CGI::Session');
};



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


