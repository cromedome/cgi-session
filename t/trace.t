# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id$

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN { 
    # check against certian dependencies here...
    my @required = qw();
    for my $mod ( @required ) {
        eval "require $mod";
        if ( $@ ) {
            print "1..0\n";
            exit(0);
        }
    }

    require Test;
    Test->import();
    
    plan(tests => 2); 
};

use CGI::Session;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $s = new CGI::Session(undef, undef, {Directory=>'t'});
ok($s);

$s->trace(1, "t/trace.log");
$s->tracemsg("This is a test trace message");



