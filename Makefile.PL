use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

print "WARNING\n";
print "=" x 50, "\n";
print "This is alpha release!\n\n";

WriteMakefile(

    'NAME'		=> 'CGI::Session',
    'VERSION_FROM'	=> 'Session.pm', # finds $VERSION
    'PREREQ_PM'		=> {Digest::MD5=>undef}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT => 'Persistent storage of complex data in CGI applications', # retrieve abstract from module
       AUTHOR     => 'Sherzod Ruzmetov <sherzodr@cpan.org>') : ()),
);
