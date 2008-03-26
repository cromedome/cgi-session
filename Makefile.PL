# $Id$

use strict;
use Text::Wrap;
use File::Spec;
use lib './t/lib';
use ExtUtils::MakeMaker;

print "-" x 40, "\n";
print fill("", "", <<'MESSAGE');
#### WARNING ####

If you are using custom CGI::Session drivers they may not be compatible with the current driver specifications. You will need to make some changes to your drivers' code before proceeding with this installation to make it compatible with CGI::Session 4.x.

Fortunately, current driver specifications are a lot easier to adapt to. Should you have any assistance re-coding your current drivers, please let me know.

Current driver specs are documented in CGI/Session/Driver.pm

#### TESTING #####

You are encouraged to run tests for the backend you will be using. The database backends that need a customized connection string won't run by default. To run them, some environment variables must be set.

The simplest method is to use the standard "DBI_DSN/DBI_USER/DBI_PASS" environment variables.

Otherwise, you can set these variables:
MESSAGE

print "
For PostgreSQL:
    CGISESS_PG_DSN
    CGISESS_PG_USER
    CGISESS_PG_PASS

For MySQL:
    CGISESS_MYSQL_DSN
    CGISESS_MYSQL_USER
    CGISESS_MYSQL_PASS
    CGISESS_MYSQL_SOCKET
";

print "\n";
print "-" x 40, "\n";

WriteMakefile(
    NAME         => 'CGI::Session',
    VERSION_FROM => 'lib/CGI/Session.pm',
    PL_FILES     => {},
    PREREQ_PM    => {
        'Digest::MD5'   => undef,
        'Data::Dumper'  => undef,
        'Test::More'    => undef,
        'Scalar::Util'  => undef,
    },
    ABSTRACT => 'Persistent session data in CGI applications',
    AUTHOR   => 'Sherzod Ruzmetov <sherzodr@cpan.org>',
    clean    => { FILES => [ 't/cgisess.*', 't/sessiondata' ] },
);

#
# Creating place for test-scripts. Some of the scripts needs this to be present
#
mkdir(File::Spec->catfile('t', 'sessiondata'));



package MY;
use strict;




sub postamble {
    return <<'MAKE_TEXT';
prepare_dist ::	metafile manifest dist
	$(NOECHO) $(NOOP)
MAKE_TEXT
}




sub libscan {
    my ($self, $path) = @_;
    return '' if $path =~ m/\.svn/;
    return $path;
}


