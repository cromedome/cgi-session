#!/usr/bin/perl -w

# $Id$

use constant LIB => '../lib';
use constant TEMP => '../tmp';

use strict;
use lib LIB;
use CGI::Session::Test;

my $obj = new CGI::Session::Test(temp_folder=>TEMP);

$obj->run();



