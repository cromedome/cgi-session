use ExtUtils::MakeMaker;
# $Id$


sub MY::postamble {
    return <<'TAG';
upload: dist
	cpan-upload$(DISTVNAME).tar$(SUFFIX)
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




