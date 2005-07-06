# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: api3_file_freezethaw_incr.t,v 1.2 2002/11/22 22:54:41 sherzodr Exp $
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN { 
    # Check if DB_File is avaialble. Otherwise, skip this test
    eval 'require FreezeThaw';
    if ( $@ ) {
        print "1..0\n";
        exit(0);
    }    

    require Test;
    Test->import();
    
    plan(tests => 14); 
};

use File::Spec;
use CGI::Session qw/-api3/;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $dr_args = {Directory=>'t', IDFile=>File::Spec->catfile('t', 'cgisess.id')};
my $args    = "driver:File;serializer;FreezeThaw;id:Incr";

my $s = new CGI::Session($args, undef, $dr_args );

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

my $s2 = new CGI::Session($args, $sid, $dr_args);

ok($s2);
ok($s2->id() eq $sid);
ok($s2->param('email'));
ok($s2->param('author'));
ok($s2->expire());

$s2->delete();

