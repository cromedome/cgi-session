
use strict;
use ExtUtils::MakeMaker;

# $Id$


sub MY::postamble {
    return <<'TAG';
upload: dist
	cpan-upload $(DISTVNAME).tar$(SUFFIX)

DOC_BASE = /home/sherzodr/public_html/modules/CGI
publish: all test dist
	mv $(DISTVNAME).tar$(SUFFIX) /home/sherzodr/public_html/modules/dist/
	$(RM_RF)  $(DOC_BASE)
	$(MKPATH) $(DOC_BASE)/Session/Serialize
	$(MKPATH) $(DOC_BASE)/Session/ID

	pod2html Session.pm > $(DOC_BASE)/Session.html
	
	pod2html Session/File.pm > $(DOC_BASE)/Session/File.html
	pod2html Session/DB_File.pm > $(DOC_BASE)/Session/DB_File.html
	pod2html Session/MySQL.pm > $(DOC_BASE)/Session/MySQL.html

	pod2html Session/Serialize/Default.pm > $(DOC_BASE)/Session/Serialize/Default.html
	pod2html Session/Serialize/Storable.pm > $(DOC_BASE)/Session/Serialize/Storable.html
	pod2html Session/Serialize/FreezeThaw.pm > $(DOC_BASE)/Session/Serialize/FreezeThaw.html
	
	pod2html Session/ID/Incr.pm > $(DOC_BASE)/Session/ID/Incr.html
	pod2html Session/ID/MD5.pm > $(DOC_BASE)/Session/ID/MD5.html	

	pod2html Session/Tutorial.pm > $(DOC_BASE)/Session/Tutorial.html
	#pod2html Session/CookBook.pm > $(DOC_BASE)/Session/CookBook.html
TAG
}



WriteMakefile(
    NAME            => 'CGI::Session',
    VERSION_FROM    => 'Session.pm',
    PREREQ_PM       => {
                    Digest::MD5 => undef,
    },
    ABSTRACT        => 'Persistent session in CGI applications',
    AUTHOR          => 'Sherzod Ruzmetov <sherzodr@cpan.org>',
);


