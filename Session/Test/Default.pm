package CGI::Session::Test::Default;

use strict;
use diagnostics;

use Carp;
use Test::More qw(no_plan);

use_ok("CGI::Session");

sub new {
    my $class   = shift;
    my $self    = bless {
            dsn     => {},
            args    => {},
            @_
    }, $class;

    return $self;
}



sub dsn_as_string {
    my $self = shift;

    my @pairs = ();
    while (my($k, $v) = each %{ $self->{dsn} } ) {
        push @pairs, $k . ':' . $v;
    }

    return "" unless @pairs;
    return join (';', @pairs);
}






sub run {
    my $self = shift;

    my $sid = undef;
    FIRST: {
        my $session = CGI::Session->new($self->dsn_as_string, undef, $self->{args});
        ok( $session, "session created");

        ok( $session->ctime, "ctime set");
        ok( $session->atime, "atime not set yet");
        ok( $session->atime == $session->ctime, "ctime == atime");
        ok( !$session->etime, "etime not set yet");

        ok( $session->id, "session id is " . $session->id);

        $session->param('author', "Sherzod Ruzmetov");
        $session->param(-name=>'emails', -value=>['sherzodr@cpan.org', 'sherzodr@handalak.com']);
        $session->param('blogs', {
            './lost+found'              => 'http://author.handalak.com/',
            'Yigitlik sarguzashtlari'   => 'http://author.handalak.com/uz/'
        });

        ok( ($session->param) == 3, "session holds 3 params" . scalar $session->param );
        ok( $session->param('author') eq "Sherzod Ruzmetov", "My name's correct!");

        ok( ref ($session->param('emails')) eq 'ARRAY', "'emails' holds list of values" );
        ok( @{ $session->param('emails') } == 2, "'emails' holds list of two values");
        ok( $session->param('emails')->[0] eq 'sherzodr@cpan.org', "first value of 'emails' is 'sherzodr\@cpan.org'");
        ok( $session->param('emails')->[1] eq 'sherzodr@handalak.com', "second value of 'emails' is 'sherzodr\@handalak.com'");

        ok( ref( $session->param('blogs') ) eq 'HASH', "'blogs' holds a hash");
        ok( $session->param('blogs')->{'./lost+found'} eq 'http://author.handalak.com/', "address of './lost+found' is correct");
        ok( $session->param('blogs')->{'Yigitlik sarguzashtlari'} eq 'http://author.handalak.com/uz/', "Yigitlik sarguzashtlari");

        $sid = $session->id;
    }

    sleep(1);

    SECOND: {
        my $session = CGI::Session->instance($self->dsn_as_string, $sid, $self->{args});
        ok($session, "session was retreived successfully");
        ok(!$session->expired, "Session isn't expired yet");

        ok($session->id eq $sid, "session IDs are consistent");
        ok($session->atime > $session->ctime, "ctime is older than atime");
        ok(!$session->etime, "etime still not set");

        ok( ($session->param) == 3, "session holds 3 params" );
        ok( $session->param('author') eq "Sherzod Ruzmetov", "My name's correct");

        ok( ref ($session->param('emails')) eq 'ARRAY', "'emails' holds list of values" );
        ok( @{ $session->param('emails') } == 2, "'emails' holds list of two values");
        ok( $session->param('emails')->[0] eq 'sherzodr@cpan.org', "first value of 'emails' is 'sherzodr\@cpan.org'");
        ok( $session->param('emails')->[1] eq 'sherzodr@handalak.com', "second value of 'emails' is 'sherzodr\@handalak.com'");

        ok( ref( $session->param('blogs') ) eq 'HASH', "'blogs' holds a hash");
        ok( $session->param('blogs')->{'./lost+found'} eq 'http://author.handalak.com/', "address of './lost+found' is correct");
        ok( $session->param('blogs')->{'Yigitlik sarguzashtlari'} eq 'http://author.handalak.com/uz/');

        $session->expire('5s');
        ok($session->etime, "etime set");
    }


    sleep(6);   # <-- have to wait untill the session expires!

    THREE: {
        my $session = CGI::Session->instance($self->dsn_as_string, $sid, $self->{args});
        ok($session, "session instance loaded");
        #print $session->dump;
        ok($session->expired, "session was expired");

        $session = CGI::Session->new( $session );
        ok($session, "new session created");
        ok($session->id, "session has id");
        ok(!$session->expired, "session isn't expired");
        ok(!$session->empty, "session isn't empty");

        ok($session->id ne $sid, "it's a completely different session than above");
    }

}



1;
