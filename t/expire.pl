# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id$

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

BEGIN { 
    # check against certian dependencies here...
    my @required = qw(IO::Dir);
    for my $mod ( @required ) {
        eval "require $mod";
        if ( $@ ) {
            print "1..0\n";
            exit(0);
        }
    }

    require Test;
    Test->import();
    
    plan(tests => 1); 
};

use blib;
use Fcntl qw(:DEFAULT :mode);
use CGI::Session;

ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

CGI::Session->verbose(1);

tie (my %dir, "IO::Dir", ".") or die $!;
while ( my ($filename, $stat) = each %dir ) {
    if ( S_ISDIR($stat->mode) ) {        
        next;
    }
    my ($sid) = $filename =~ m/^cgisess_(.+)$/ or next;    
    
    $CGI::Session::TOUCH = 1;
    CGI::Session->new("dr:File", $sid, {Directory=>"."});

    
}

untie(%dir);
    