# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id$
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 7  };
use CGI::Session::File;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.
$CGI::Session::File::FileName = 'cgisession_%s.txt';
my $s = new CGI::Session::File(undef, {Directory=>"t"} )
    or die $CGI::Session::errstr;

ok($s);
ok($s->id());

my $d1 = [qw(1 2 3 4 5 6)];
my $d2 = {1 => "Bir", 2 => "Ikki", 3=>"Uch", 4=>"To'rt", 5=>"Besh", 6=>"Olti"};
my $d3 = {
        d1 => $d1,
        d2 => $d2
};

$s->param(d3 => $d3);

ok($s->param('d3'));

ok( $s->param('d3')->{d1}->[0], 1);

ok( $s->param('d3')->{d1}->[1], 2);

ok( $s->param('d3')->{d2}->{1}, 'Bir');


