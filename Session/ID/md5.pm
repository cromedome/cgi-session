package CGI::Session::ID::md5;

# $Id$

use strict;
#use diagnostics;

use Digest::MD5;

$CGI::Session::ID::md5::VERSION = '1.2';

*generate = \&generate_id;
sub generate_id {
    my $md5 = new Digest::MD5();
    $md5->add($$ , time() , rand(time) );
    return $md5->hexdigest();
}


1;

=pod

=head1 NAME

CGI::Session::ID::MD5 - default CGI::Session ID generator

=head1 SYNOPSIS

    use CGI::Session;
    $s = new CGI::Session("id:MD5", undef);

=head1 DESCRIPTION

CGI::Session::ID::MD5 is to generate MD5 encoded hexidecimal random ids. The library does not require any arguments. 

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut
