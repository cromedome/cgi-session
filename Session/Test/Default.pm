package CGI::Session::Test::Default;

use strict;
use diagnostics;
use overload;
use Carp;
use Test::More;
use Data::Dumper;

$CGI::Session::Test::Default::VERSION = '1.3';


sub new {
    my $class   = shift;
    my $self    = bless {
            dsn     => "driver:file",
            args    => undef,
            tests   => 77,
            @_
    }, $class;

    return $self;
}

sub number_of_tests {
    my $self = shift;

    if ( @_ ) {
        $self->{tests} = $_[0];
    }

    return $self->{tests};
}





sub run {
    my $self = shift;
    
    plan(tests => $self->{tests});

    use_ok("CGI::Session", "CGI::Session loaded successfully!");

    my $sid = undef;
    FIRST: {
        ok(1, "=== 1 ===");
        my $session = CGI::Session->load() or die CGI::Session->errstr;
        ok($session, "empty session should be created");
        ok(!$session->id);
        ok($session->is_empty);
        ok(!$session->is_expired);

        undef $session;

        $session = CGI::Session->new($self->{dsn}, '_DOESN\'T EXIST_', $self->{args}) or die CGI::Session->errstr;
        ok( $session, "Session created successfully!");

        #
        # checking if the driver object created is really the driver requested:
        #
        my $dsn = $session->parse_dsn( $self->{dsn} );
        ok( ref $session->_driver eq "CGI::Session::Driver::" . $dsn->{driver}, ref $dsn->{Driver} );

        ok( $session->ctime && $session->atime, "ctime & atime are set");
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
        ok( $session->param('emails')->[0] eq 'sherzodr@cpan.org', "first value of 'emails' is correct!");
        ok( $session->param('emails')->[1] eq 'sherzodr@handalak.com', "second value of 'emails' is correct!");

        ok( ref( $session->param('blogs') ) eq 'HASH', "'blogs' holds a hash");
        ok( $session->param('blogs')->{'./lost+found'} eq 'http://author.handalak.com/', "first blog is correct");
        ok( $session->param('blogs')->{'Yigitlik sarguzashtlari'} eq 'http://author.handalak.com/uz/', "second blog is correct");

        $sid = $session->id;
    }

    sleep(1);

    SECOND: {
        ok(1, "=== 2 ===");
        my $session = CGI::Session->load($self->{dsn}, $sid, $self->{args}) or die CGI::Session->errstr;
        ok($session, "Session was retreived successfully");
        ok(!$session->is_expired, "session isn't expired yet");

        ok($session->id eq $sid, "session IDs are consistent: " . $session->id);
        ok($session->atime > $session->ctime, "ctime should be older than atime");
        ok(!$session->etime, "etime shouldn't be set yet");

        ok( ($session->param) == 3, "session should hold params" );
        ok( $session->param('author') eq "Sherzod Ruzmetov", "my name's correct");

        ok( ref ($session->param('emails')) eq 'ARRAY', "'emails' should hold list of values" );
        ok( @{ $session->param('emails') } == 2, "'emails' should hold list of two values");
        ok( $session->param('emails')->[0] eq 'sherzodr@cpan.org', "first value is correct!");
        ok( $session->param('emails')->[1] eq 'sherzodr@handalak.com', "second value is correct!");

        ok( ref( $session->param('blogs') ) eq 'HASH', "'blogs' holds a hash");
        ok( $session->param('blogs')->{'./lost+found'} eq 'http://author.handalak.com/', "first blog is correct!");
        ok( $session->param('blogs')->{'Yigitlik sarguzashtlari'} eq 'http://author.handalak.com/uz/', "second blog is correct!");

        $session->expire('1s');
        ok($session->etime, "etime set");
    }


    sleep(1);   # <-- have to wait until the session expires!

    my $driver;
    THREE: {
        ok(1, "=== 3 ===");
        my $session = CGI::Session->load($self->{dsn}, $sid, $self->{args}) or die CGI::Session->errstr;
        ok($session, "Session instance loaded");
        ok(!$session->id, "session doesn't have ID");
        ok($session->is_empty, "session is empty, which is the same as above");
        #print $session->dump;
        ok($session->is_expired, "session was expired");
        ok(!$session->param('author'), "session data cleared");

        sleep(1);

        $session = $session->new() or die CGI::Session->errstr;
        #print $session->dump();
        ok($session, "new session created");
        ok($session->id, "session has id :" . $session->id );
        ok(!$session->is_expired, "session isn't expired");
        ok(!$session->is_empty, "session isn't empty");
        ok($session->atime == $session->ctime, "access and creation times are same");

        ok($session->id ne $sid, "it's a completely different session than above");

        $driver     = $session->_driver();
        $sid        = $session->id;
    }



    FOUR: {
        # We are intentionally removing the session stored in the datastore and will be requesting
        # re-initilization of that id. This test is necessary since I noticed weird behaviours in
        # some of my web applications that kept creating new sessions when the object requested
        # wasn't in the datastore.
        ok(1, "=== 4 ===");

        ok($driver->remove( $sid ), "Session '$sid' removed from datastore successfully");

        my $session = CGI::Session->new($self->{dsn}, $sid, $self->{args} ) or die CGI::Session->errstr;
        ok($session, "session object created successfully");
        ok($session->id ne $sid, "claimed ID ($sid) couldn't be recovered. New ID is: " . $session->id);
        $sid = $session->id;
    }


    
    FIVE: {
        ok(1, "=== 5 ===");
        my $session = CGI::Session->new($self->{dsn}, $sid, $self->{args}) or die CGI::Session->errstr;
        ok($session, "Session object created successfully");
        ok($session->id eq $sid, "claimed id ($sid) was recovered successfully!");

        # Remove the object, finally!
        $session->delete();
    }


    SIX: {
        ok(1, "=== 6 ===");
        my $session = CGI::Session->new($self->{dsn}, $sid, $self->{args}) or die CGI::Session->errstr;
        ok($session, "Session object created successfully");
        ok($session->id ne $sid, "New object created, because previous object was deleted");
        $sid = $session->id;

        #
        # creating a simple object to be stored into session
        my $simple_class = SimpleObjectClass->new();
        ok($simple_class, "SimpleObjectClass created successfully");

        $simple_class->name("Sherzod Ruzmetov");
        $simple_class->emails(0, 'sherzodr@handalak.com');
        $simple_class->emails(1, 'sherzodr@cpan.org');
        $simple_class->blogs('lost+found', 'http://author.handalak.com/');
        $simple_class->blogs('yigitlik', 'http://author.handalak.com/uz/');
        $session->param('simple_object', $simple_class);

        ok($session->param('simple_object')->name eq "Sherzod Ruzmetov");
        ok($session->param('simple_object')->emails(1) eq 'sherzodr@cpan.org');
        ok($session->param('simple_object')->blogs('yigitlik') eq 'http://author.handalak.com/uz/');

        #
        # creating an overloaded object to be stored into session
        my $overloaded_class = OverloadedObjectClass->new("ABCDEFG");
        ok($overloaded_class, "OverloadedObjectClass created successfully");
        ok(overload::Overloaded($overloaded_class) , "OverloadedObjectClass is properly overloaded");
        ok(ref ($overloaded_class) eq "OverloadedObjectClass", "OverloadedObjectClass is an object");
        $session->param("overloaded_object", $overloaded_class);

        ok($session->param("overloaded_object") eq "ABCDEFG");

    }


    SEVEN: {
        ok(1, "=== 7 ===");
        my $session = CGI::Session->new($self->{dsn}, $sid, $self->{args}) or die CGI::Session->errstr;
        ok($session, "Session object created successfully");
        ok($session->id eq $sid, "Previously stored object loaded successfully");

        
        my $simple_object = $session->param("simple_object");
        ok(ref $simple_object eq "SimpleObjectClass", "SimpleObjectClass loaded successfully");

        SKIP: {
            my $dsn = CGI::Session->parse_dsn($self->{dsn});
            if ( !$dsn->{serializer} || ($dsn->{serializer} eq 'default') ) {
                skip("Default serializer cannot serialize objects properly", 6);
            }
            ok($simple_object->name eq "Sherzod Ruzmetov");
            ok($simple_object->emails(1) eq 'sherzodr@cpan.org');
            ok($simple_object->emails(0) eq 'sherzodr@handalak.com');
            ok($simple_object->blogs('lost+found') eq 'http://author.handalak.com/');
            ok(ref $session->param("overloaded_object") );
            ok($session->param("overloaded_object") eq "ABCDEFG", "Object is still overloaded");
        }
        $session->delete();
    }
}


package SimpleObjectClass;
use strict;
use Class::Struct;

struct (
    name    => '$',
    emails  => '@',
    blogs   => '%'
);



package OverloadedObjectClass;

use strict;
use overload (
    '""'    => \&as_string,
    'eq'    => \&equals
);


sub new {
    return bless {
        str_value => $_[1]
    }, $_[0];
}


sub as_string {
    return $_[0]->{str_value};
}

sub equals {
    my ($self, $arg) = @_;

    return ($self->as_string eq $arg);
}


1;
