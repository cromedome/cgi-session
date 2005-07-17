# Some unit tests for CGI::Session::Driver::DBI
BEGIN{ 
    use Test::More qw/no_plan/;
    use_ok('CGI::Session::Driver::DBI');
}

eval { CGI::Session::Driver::DBI->retrieve(undef); };
like($@,qr/\Qretrieve(): usage error/,'retrieve returns expected failure message when no session id is given'); 

eval { CGI::Session::Driver::DBI->traverse(undef); };
like($@,qr/\Qtraverse(): usage error/,'traverse returns expected failure message when no session id is given'); 







