use strict;
use diagnostics;

use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

eval "require DB_File";
if ( $@ ) {
    plan(skip_all=>"DB_File is NOT available");
    exit(0);
}

my $dir_name = File::Spec->tmpdir;
my $t = CGI::Session::Test::Default->new(
    dsn => "DR:db_file",
    args=>{FileName => File::Spec->catfile($dir_name, 'cgisess.db')});

plan tests => $t->number_of_tests;
$t->run();
