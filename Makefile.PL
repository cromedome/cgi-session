# $Id$

use strict;
use Text::Wrap;
use lib './t/lib';
use ExtUtils::MakeMaker;

print "-" x	40,	"\n";
print fill("", "", <<'MESSAGE');
#### WARNING ####

If you are using custom	CGI::Session drivers they may not be compatible	with the current driver	specifications.	
You will need to make some changes to your drivers' code before proceeding with this installation to make it 
compatible with	CGI::Session 4.x.

Fortunately, current driver specifications are a lot easier to adapt to. Should you have any assistance	
re-coding your current drivers,	please let me know.

Current driver specs are documented in CGI/Session/Driver.pm
MESSAGE

print "\n";
print "-" x	40,	"\n";

WriteMakefile(
	NAME			=> 'CGI::Session',
	VERSION_FROM	        => 'lib/CGI/Session.pm',
	PREREQ_PM		=> {
		'Digest::MD5'	=> undef,
		'Data::Dumper'	=> undef,
		'Test::More'	=> undef,
	},
	ABSTRACT		=> 'Persistent session data in CGI applications',
	AUTHOR			=> 'Sherzod Ruzmetov <sherzodr@cpan.org>',
);


package MY;

use strict;

sub postamble {
    return <<'MAKE_TEXT';
prepare_dist :: metafile manifest dist
	$(NOECHO) $(NOOP)
MAKE_TEXT
}

sub libscan {
    my ($self, $path) = @_;
    return '' if $path =~ m/\.svn/;
    return $path;
}


