#!/usr/bin/perl -w

# $Id$

use constant LIB => '../lib';
use constant TEMP => '/home/sherzodr/public_html/modules/tmp';

use CGI::Carp "fatalsToBrowser";
use strict;
use lib LIB;
use CGI::Session::Test;

my $obj = new CGI::Session::Test( PARAMS => {temp=>TEMP} );

$obj->run();



