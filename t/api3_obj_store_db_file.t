# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# $Id: api3_obj_store_db_file.t,v 1.3.6.1 2003/07/26 13:37:36 sherzodr Exp $
#########################

# change 'tests => 1' to 'tests => last_test_to_print';


use CGI;
use CGI::Session;

eval "require DB_File";
if ( $@ ) {
    print "1..0 #Skipped: DB_File is not available\n";
    exit(0)
}

my @mods = qw(Storable FreezeThaw);

my $ser = undef;
for ( @mods ) {
    eval "require $_";
    unless ( $@ ) {
        $ser = $_;
        next;
    }
}

unless ( $ser ) {
    print "1..0 #Skipped: Neither Storable nor FreezeThaw avaialble\n";
    exit(0);
}

my $args = "driver:DB_File;serializer:$ser";
my $dr_args = {Directory=>'t'};

print "1..8\n";

my $cgi = new CGI;
my $s   = new CGI::Session($args, undef, $dr_args);


print defined($s) ? "ok\n" : "not ok\n";
print $s->id() ? "ok\n" : "not ok\n";

$cgi->param(name => 'Sherzod');

print $cgi->param('name') ? "ok\n" : "not ok\n";
print $s->param(_CGI => $cgi) ? "ok\n" : "not ok\n";

my $sid = $s->id();

$s->flush();

my $s2 = new CGI::Session($args, $sid, $dr_args);
print defined($s2) ? "ok\n" : "not ok\n";

print $s2->id eq $sid ? "ok\n" : "not ok\n";

my $old_cgi = $s2->param('_CGI');

print ref($old_cgi) ? "ok\n" : "not ok\n";

print $old_cgi->param('name') eq 'Sherzod' ? "ok\n" : "not ok\n";


$s2->delete();
