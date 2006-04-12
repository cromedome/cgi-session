# $Id$

use strict;
use diagnostics;

use Test::More;
use File::Spec;
use CGI::Session::Test::Default;

our %serializers;

# If you add a new option here, update the skip_all msg below. 
our %options = (
    'JSON::Syck'      =>  { skip    =>  [85 .. 89, 91 .. 101] },
);

plan skip_all => 'DB_File is NOT available' unless eval { require DB_File };

foreach my $i (keys(%options)) {
    $serializers{$i}++ if eval "use $i (); 1";
}

unless(%serializers) {
    plan skip_all => "JSON::Syck is not available.";
}

my @test_objects;

while(my($k, $v) = each(%serializers)) {
    push(@test_objects, CGI::Session::Test::Default->new(
        dsn => "d:DB_File;s:JSON;id:md5",
        args => {
            FileName => File::Spec->catfile('t', 'sessiondata', 'cgisess.db'),
        },
        %{$options{$k}},
        __testing_serializer => $k,
    ));
}

my $tests = 0;
$tests += $_->number_of_tests foreach @test_objects;
plan tests => $tests;

foreach my $to (@test_objects) {
    $CGI::Session::Serialize::json::Flavour = $to->{__testing_serializer};
    diag($CGI::Session::Serialize::json::Flavour);
    $to->run();
}
