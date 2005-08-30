# $Id$

use strict;
use diagnostics;

use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

eval { require Storable };
plan(skip_all=>"Storable is NOT available") if $@;

my $t = CGI::Session::Test::Default->new(
    dsn => "driver:file;serializer:Storable",
    args=>{Directory=>File::Spec->catdir('t', 'sessiondata')});

plan tests => $t->number_of_tests;
$t->run();
