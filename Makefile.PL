# $Id$

use strict;
use ExtUtils::MakeMaker;

print "-" x 35, "\n";
print ".::WARNING::.\n";
print "-" x 35, "\n";
print "This is the development release\n";
print "-" x 35, "\n";

sub MY::postamble {
    return <<'TAG';
realclean::
	$(RM_RF) blib/
	$(RM_F) Makefile Makefile.old t/cgisess.*

upload: dist
	cpan-upload $(DISTVNAME).tar$(SUFFIX)

DOC_BASE = /home/sherzodr/public_html/modules/CGI
POD2HTML = pod2html --backlink="[toc]" --podroot=/usr/lib/perl5/5.6.1 \
	                               --recurse --header --css=style.css
publish: dist
	mv $(DISTVNAME).tar$(SUFFIX) /home/sherzodr/public_html/modules/dist/
	$(RM_RF)  $(DOC_BASE)
	$(MKPATH) $(DOC_BASE)/Session/Serialize
	$(MKPATH) $(DOC_BASE)/Session/ID

	$(POD2HTML) Session.pm > $(DOC_BASE)/Session.html
	
	$(POD2HTML) Session/File.pm > $(DOC_BASE)/Session/File.html
	$(POD2HTML) Session/DB_File.pm > $(DOC_BASE)/Session/DB_File.html
	$(POD2HTML) Session/MySQL.pm > $(DOC_BASE)/Session/MySQL.html

	$(POD2HTML) Session/Serialize/Default.pm > $(DOC_BASE)/Session/Serialize/Default.html
	$(POD2HTML) Session/Serialize/Storable.pm > $(DOC_BASE)/Session/Serialize/Storable.html
	$(POD2HTML) Session/Serialize/FreezeThaw.pm > $(DOC_BASE)/Session/Serialize/FreezeThaw.html
	
	$(POD2HTML) Session/ID/Incr.pm > $(DOC_BASE)/Session/ID/Incr.html
	$(POD2HTML) Session/ID/MD5.pm > $(DOC_BASE)/Session/ID/MD5.html	

	$(POD2HTML) Session/Tutorial.pm > $(DOC_BASE)/Session/Tutorial.html
	$(POD2HTML) Session/CookBook.pm > $(DOC_BASE)/Session/CookBook.html
	
	$(RM_RF) pod2htm*
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


