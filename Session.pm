package CGI::Session;

# $Id$

use strict;
use Carp ('confess', 'croak');
use AutoLoader 'AUTOLOAD';

use vars qw($VERSION $errstr $IP_MATCH $NAME $API_3 $TOUCH);

$VERSION    = '3.91';
$NAME       = 'CGISESSID';

# import() - we do not import anything into the callers namespace, however,
# we enable the user to specify hooks at compile time
sub import {
    my $class = shift;
    @_ or return;
    for ( my $i = 0; $i < @_; $i++ ) {
        $IP_MATCH   = ( $_[$i] eq '-ip_match'   ) and next;
        $API_3      = ( $_[$i] eq '-api3'       ) and next;
    }
}


# Session _STATUS flags
sub SYNCED   () { 0 }
sub MODIFIED () { 1 }
sub DELETED  () { 2 }

sub OK       () { 1 }
sub NOT_OK   () { undef }


# new() - constructor.
# Returns respective driver object
sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _OPTIONS    => [ @_ ],
        _DATA       => undef,
        _STATUS     => MODIFIED,
        _API3       => { },
        _CACHE      => { },
    };

    if ( $TOUCH ) {
        $class->_touch_init(@_);
        bless($self, $class);

    } elsif ( $API_3 || (@_ == 3 ) ) {
        return $class->api_3(@_);

    }

    bless ($self, $class);
    $self->_validate_driver() && $self->_init() or return;
    return $self;
}








# It may be possible to make the following constructor
# a little more efficient?!
sub api_3 {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _OPTIONS    => [ $_[1], $_[2] ],
        _DATA       => undef,
        _STATUS     => MODIFIED,
        _CACHE      => {},
        _API_3      => {
            DRIVER      => 'File',
            SERIALIZER  => 'Default',
            ID          => 'MD5',
        }
    };

    # supporting DSN name abbreviations:
    require Text::Abbrev;
    my $dsn_abbrev = Text::Abbrev::abbrev('driver', 'serializer', 'id');

    if ( defined $_[0] ) {
        my @arg_pairs = split (/;/, $_[0]);
        for my $arg ( @arg_pairs ) {
            my ($key, $value) = split (/:/, $arg) or next;
            $key = $dsn_abbrev->{$key};
            $self->{_API_3}->{ uc($key) } = $value || $self->{_API_3}->{uc($key)};
        }
    }

    my $driver = "CGI::Session::$self->{_API_3}->{DRIVER}";
    eval "require $driver" or carp($@);


    my $serializer = "CGI::Session::Serialize::$self->{_API_3}->{SERIALIZER}";  
    eval "require $serializer" or carp($@);

    my $id = "CGI::Session::ID::$self->{_API_3}->{ID}";
    eval "require $id" or carp($@);

    # Now re-defining the driver's ISA according to what we have above
    {
        no strict 'refs';
        @{$driver . "::ISA"} = ( $class, $serializer, $id );
    }

    bless ($self, $driver);

    $self->_validate_driver() && $self->_init() or return;
    
    return $self;
}





# touch() - experimental
sub touch {
    my $class = shift;

    $CGI::Session::TOUCH = 1;
    return $class->new(@_);
}









# DESTROY() - destructor.
# Flushes the memory, and calls driver's teardown()
sub DESTROY {
    my $self = shift;

    $self->flush();
    $self->can('teardown') && $self->teardown();

    my $fh = $self->{_TRACE_FH};

    if ( defined $fh ) {
        print $fh "-" x 36, "\n";
        CORE::close( $fh );
    }
}


# options() - used by drivers only. Returns the driver
# specific options. To be used in the future releases of the
# library, may be. Experimental!
sub driver_options {
    my $self = shift;

    return $self->{_OPTIONS}->[1];
}

# _validate_driver() - checks driver's validity.
# Return value doesn't matter. If the driver doesn't seem
# to be valid, it croaks
sub _validate_driver {
    my $self = shift;

    my @required = qw(store retrieve remove generate_id);

    for my $method ( @required ) {
        unless ( $self->can($method) ) {
            my $class = ref($self);
            confess "$class doesn't seem to be a valid CGI::Session driver. " .
                "At least one method ('$method') is missing";
        }
    }
    return 1;
}




# _init() - object initialializer.
# Decides between _init_old_session() and _init_new_session()
sub _init {
    my $self = shift;

    # default behavior is to assume no id at all.
    my $claimed_id = undef;

    # Getting the first argument passed to new (in api3 syntax, it's
    # actually the second argument)
    my $arg = $self->{_OPTIONS}->[0];

    # Checking if that argument is defined, and if it is, is it a reference
    # or instance of some object
    if ( defined($arg) && ref($arg) ) {

        # Check if we're getting instance of CGI object...
        if ( $arg->isa('CGI') ) {
            # .. in which case, try to retrieve the claimed session id
            # from either HTTP cookie or query string.
            $claimed_id = $arg->cookie($NAME) || $arg->param($NAME) || undef;

        # Otherwise check if we're getting a reference to some code...
        } elsif ( ref($arg) eq 'CODE' ) {

            # ... and try to call that code and use its return value as a
            # claimed id.
            $claimed_id = $arg->($self) || undef;
        }

    # If the argument is defined, but not a reference, treat it literally as
    # claimed session id
    } elsif ( defined($arg) ) {
        $claimed_id = $arg;
    }


    # If claimed id is defined, try to initialize already existing session
    # data from disk...
    if ( defined $claimed_id ) {
        my $rv = $self->_init_old_session($claimed_id);

        # ...If the data couldn't be restored, initialize a new session
        # NOTE: currently, the value holding $rv is either true or false.
        # We could work out a little more explicit rule, for, for example
        # unexisting sessions, new sessions or corrupted sessions. 
        unless ( $rv ) {
            return $self->_init_new_session();
        }
        return 1;
    }
    return $self->_init_new_session();
}




# _init_old_session() - tries to retieve the old session.
# If suceeds, checks if the session is expirable. If so, deletes it
# and returns undef so that _init() creates a new session.
# Otherwise, checks if there're any parameters to be expired, and
# calls clear() if any. Aftewards, updates atime of the session, and
# returns true
sub _init_old_session {
    my ($self, $claimed_id) = @_;

    my $options = $self->{_OPTIONS} || [];
    my $data = $self->retrieve($claimed_id, $options);

    # Session was initialized successfully
    if ( defined $data ) {

        $self->{_DATA} = $data;

        # Check if the IP of the initial session owner should
        # match with the current user's IP
        if ( $IP_MATCH ) {
            unless ( $self->_ip_matches() ) {
                $self->delete();
                $self->flush();
                return undef;
            }
        }

        # Check if the session's expiration ticker is up
        if ( $self->_is_expired() ) {
            $self->delete();
            $self->flush();
            return undef;
        }

        # Expring single parameters, if any
        $self->_expire_params();

        # Updating last access time for the session
        $self->{_DATA}->{_SESSION_ATIME} = time();

        # Marking the session as modified
        $self->{_STATUS} = MODIFIED;

        return 1;
    }
    return undef;
}





sub _ip_matches {
    return ( $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR} eq $ENV{REMOTE_ADDR} );
}





# _is_expired() - returns true if the session is to be expired.
# Called from _init_old_session() method.
sub _is_expired {
    my $self = shift;

    unless ( $self->expire() ) {
        return undef;
    }

    return ( time() >= ($self->expire() + $self->atime() ) );
}





# _expire_params() - expires individual params. Called from within
# _init_old_session() method on a sucessfully retrieved session
sub _expire_params {
    my $self = shift;

    # Expiring
    my $exp_list = $self->{_DATA}->{_SESSION_EXPIRE_LIST} || {};
    my @trash_can = ();
    while ( my ($param, $etime) = each %{$exp_list} ) {
        if ( time() >= ($self->atime() + $etime) ) {
            push @trash_can, $param;
        }
    }

    if ( @trash_can ) {
        $self->clear(\@trash_can);
    }
}





# _init_new_session() - initializes a new session
sub _init_new_session {
    my $self = shift;

    $self->{_DATA} = {
        _SESSION_ID => $self->generate_id($self->{_OPTIONS}),
        _SESSION_CTIME => time(),
        _SESSION_ATIME => time(),
        _SESSION_ETIME => undef,
        _SESSION_REMOTE_ADDR => $ENV{REMOTE_ADDR} || undef,
        _SESSION_EXPIRE_LIST => { },
    };

    $self->{_STATUS} = MODIFIED;

    return 1;
}




# id() - accessor method. Returns effective id
# for the current session. CGI::Session deals with
# two kinds of ids; effective and claimed. Claimed id
# is the one passed to the constructor - new() as the first
# argument. It doesn't mean that id() method returns that
# particular id, since that ID might be either expired,
# or even invalid, or just data associated with that id
# might not be available for some reason. In this case,
# claimed id and effective id are not the same.
sub id {
    my $self = shift;

    return $self->{_DATA}->{_SESSION_ID};
}



# param() - accessor method. Reads and writes
# session parameters ( $self->{_DATA} ). Decides
# between _get_param() and _set_param() accordingly.
sub param {
    my $self = shift;

    unless ( defined $_[0] ) {
        return keys %{ $self->{_DATA} };
    }

    if ( @_ == 1 ) {
        return $self->_get_param(@_);
    }

    # If it has more than one arguments, let's try to figure out
    # what the caller is trying to do, since our tricks are endless ;-)
    my $arg = {
        -name   => undef,
        -value  => undef,
        @_,
    };

    if ( defined($arg->{'-name'}) && defined($arg->{'-value'}) ) {
        return $self->_set_param($arg->{'-name'}, $arg->{'-value'});

    }

    if ( defined $arg->{'-name'} ) {
        return $self->_get_param( $arg->{'-name'} );
    }

    if ( @_ == 2 ) {
        return $self->_set_param(@_);
    }

    unless ( @_ % 2 ) {
        my $n = 0;
        my %args = @_;
        while ( my ($key, $value) = each %args ) {
            $self->_set_param($key, $value) && ++$n;
        }
        return $n;
    }

    confess "param(): unknown syntax.";
}



# _set_param() - sets session parameter to the '_DATA' table
sub _set_param {
    my ($self, $key, $value) = @_;

    if ( $self->{_STATUS} == DELETED ) {
        return;
    }

    # session parameters starting with '_session_' are
    # private to the class
    if ( $key =~ m/^_SESSION_/ ) {
        return undef;
    }

    $self->{_DATA}->{$key} = $value;
    $self->{_STATUS} = MODIFIED;

    return $value;
}




# _get_param() - gets a single parameter from the
# '_DATA' table
sub _get_param {
    my ($self, $key) = @_;

    if ( $self->{_STATUS} == DELETED ) {
        return;
    }

    return $self->{_DATA}->{$key};
}


# flush() - flushes the memory into the disk if necessary.
# Usually called from within DESTROY() or close()
sub flush {
    my $self = shift;

    my $status = $self->{_STATUS};

    if ( $status == MODIFIED ) {
        $self->store($self->id, $self->{_OPTIONS}, $self->{_DATA});
        $self->{_STATUS} = SYNCED;
    }

    if ( $status == DELETED ) {
        return $self->remove($self->id, $self->{_OPTIONS});
    }

    $self->{_STATUS} = SYNCED;

    return 1;
}



# delete() - sets the '_STATUS' session flag to DELETED,
# which flush() uses to decide to call remove() method on driver.
sub delete {
    my $self = shift;

    # If it was already deleted, make a confession!
    if ( $self->{_STATUS} == DELETED ) {
        confess "delete attempt on deleted session";
    }

    $self->{_STATUS} = DELETED;
}





# clear() - clears a list of parameters off the session's '_DATA' table
sub clear {
    my $self = shift;
    my $class   = ref($self);

    my @params = $self->param();
    if ( defined $_[0] ) {
        unless ( ref($_[0]) eq 'ARRAY' ) {
            confess "Usage: $class->clear([\@array])";
        }
        @params = @{ $_[0] };
    }

    my $n = 0;
    for ( @params ) {
        /^_SESSION_/ and next;
        # If this particular parameter has an expiration ticker,
        # remove it.
        if ( $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$_} ) {
            delete ( $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$_} );
        }
        delete ($self->{_DATA}->{$_}) && ++$n;
    }

    # Set the session '_STATUS' flag to MODIFIED
    $self->{_STATUS} = MODIFIED;

    return $n;
}





# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__;


# $Id$

=pod

=head1 NAME

CGI::Session - persistent session data in CGI applications

=head1 SYNOPSIS

    # Object initialization:
    use CGI::Session;

    my $session = new CGI::Session("driver:File", undef, {Directory=>'/tmp'});

    # getting the effective session id:
    my $CGISESSID = $session->id();

    # storing data in the session
    $session->param('f_name', 'Sherzod');
    # or
    $session->param(-name=>'l_name', -value=>'Ruzmetov');

    # retrieving data
    my $f_name = $session->param('f_name');
    # or
    my $l_name = $session->param(-name=>'l_name');

    # clearing a certain session parameter
    $session->clear(["_IS_LOGGED_IN"]);

    # expire '_IS_LOGGED_IN' flag after 10 idle minutes:
    $session->expire(_IS_LOGGED_IN => '+10m')

    # expire the session itself after 1 idle hour
    $session->expire('+1h');

    # delete the session for good
    $session->delete();

=head1 DESCRIPTION

CGI-Session is a Perl5 library that provides an easy, reliable and modular
session management system across HTTP requests. Persistency is a key feature for
such applications as shopping carts, login/authentication routines, and
application that need to carry data accross HTTP requests. CGI::Session
does that and many more

=head1 TO LEARN MORE

Current manual is optimized to be used as a quick reference. To learn more both about the logic behind session management and CGI::Session programming style, consider the following:

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual. Also includes library architecture and driver specifications.

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

We also provide mailing lists for CGI::Session users. To subscribe to the list or browse the archives visit https://lists.sourceforge.net/lists/listinfo/cgi-session-user

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=head1 METHODS

Following is the overview of all the available methods accessible via
CGI::Session object.

=over 4

=item C<new( DSN, SID, HASHREF )>

Requires three arguments. First is the Data Source Name, second should be
the session id to be initialized or an object which provides either of 'param()'
or 'cookie()' mehods. If Data Source Name is undef, it will fall back
to default values, which are "driver:File;serializer:Default;id:MD5".

If session id is missing, it will force the library to generate a new session
id, which will be accessible through C<id()> method.

Examples:

    $session = new CGI::Session(undef, undef, {Directory=>'/tmp'});
    $session = new CGI::Session("driver:File;serializer:Storable", undef,  {Directory=>'/tmp'})
    $session = new CGI::Session("driver:MySQL;id:Incr", undef, {Handle=>$dbh});
    $session = new CGI::Session(undef, \&get_sid, {Directory=>'/tmp'});

Following data source variables are supported:

=over 4

=item *

C<driver> - CGI::Session driver. Available drivers are "File", "DB_File" and
"MySQL". Default is "File".

=item *

C<serializer> - serializer to be used to encode the data structure before saving
in the disk. Available serializers are "Storable", "FreezeThaw" and "Default".
Default is "Default", which uses standard L<Data::Dumper|Data::Dumper>

=item *

C<id> - ID generator to use when new session is to be created. Available ID generators
are "MD5" and "Incr". Default is "MD5".

=back

Note: you can also use unambiguous abbreviations of the DSN parameters. Examples:

    new CGI::Session("dr:File;ser:Storable", undef, {Diretory=>'/tmp'});

=item C<touch()>

Constructor. Used in cleanup scripts. Example:

    tie my %dir, "IO::Dir", "/usr/tmp";
    while ( my ($filename, $stat) = each %dir ) {
        my ($sid) = $filename = m/^cgisess_(\w{32})$/;
        CGI::Session->touch(undef, $sid, {Directory=>"/tmp"});
    }
    untie(%dir);

touch() accepts the same arguments as new() does, but it doesn't necessarily
returns object instance. It simply expires old sessions without updating their
last access time parameter.

=item C<id()>

Returns effective ID for a session. Since effective ID and claimed ID
can differ, valid session id should always be retrieved using this
method.

=item C<param($name)>

=item C<param(-name=E<gt>$name)>

this method used in either of the above syntax returns a session
parameter set to C<$name> or undef on failure.

=item C<param( $name, $value)>

=item C<param(-name=E<gt>$name, -value=E<gt>$value)>

method used in either of the above syntax assigns a new value to $name
parameter, which can later be retrieved with previously introduced
param() syntax.

=item C<param_hashref()>

returns all the session parameters as a reference to a hash


=item C<save_param($cgi)>

=item C<save_param($cgi, $arrayref)>

Saves CGI parameters to session object. In otherwords, it's calling
C<param($name, $value)> for every single CGI parameter. The first
argument should be either CGI object or any object which can provide
param() method. If second argument is present and is a reference to an 
array, only those CGI parameters found in the array will be stored in the session

=item C<load_param($cgi)>

=item C<load_param($cgi, $arrayref)>

loads session parameters to CGI object. The first argument is required
to be either CGI.pm object, or any other object which can provide
param() method. If second argument is present and is a reference to an
array, only the parameters found in that array will be loaded to CGI
object.

=item C<sync_param($cgi)>

=item C<sync_param($cgi, $arrayref)>

experimental feature. Synchronizes CGI and session objects. In other words, 
it's the same as calling respective syntaxes of save_param() and load_param().

=item C<clear()>

=item C<clear([@list])>

clears parameters from the session object. If passed an argument as an
arrayref, clears only those parameters found in the list.

=item C<flush()>

synchronizes data in the buffer with its copy in disk. Normally it will
be called for you just before the program terminates, session object
goes out of scope or close() is called.

=item C<close()>

closes the session temporarily until new() is called on the same session
next time. In other words, it's a call to flush() and DESTROY(), but
a lot slower. Normally you never have to call close().

=item C<atime()>

returns the last access time of the session in the form of seconds from
epoch. This time is used internally while auto-expiring sessions and/or session 
parameters.

=item C<ctime()>

returns the time when the session was first created.

=item C<expire()>

=item C<expire($time)>

=item C<expire($param, $time)>

Sets expiration date relative to atime(). If used with no arguments, returns 
the expiration date if it was ever set. If no expiration was ever set, returns 
undef.

Second form sets an expiration time. This value is checked when previously stored 
session is asked to be retrieved, and if its expiration date has passed will be 
expunged from the disk immediately and new session is created accordingly. 
Passing 0 would cancel expiration date.

By using the third syntax you can also set an expiration date for a
particular session parameter, say "~logged-in". This would cause the
library call clear() on the parameter when its time is up.

All the time values should be given in the form of seconds. Following
time aliases are also supported for your convenience:

    +===========+===============+
    |   alias   |   meaning     |
    +===========+===============+
    |     s     |   Second      |
    |     m     |   Minute      |
    |     h     |   Hour        |
    |     w     |   Week        |
    |     M     |   Month       |
    |     y     |   Year        |
    +-----------+---------------+

Examples:

    $session->expire("+1y");   # expires in one year
    $session->expire(0);       # cancel expiration
    $session->expire("~logged-in", "+10m");# expires ~logged-in flag in 10 mins

Note: all the expiration times are relative to session's last access time, not to 
its creation time. To expire a session immediately, call C<delete()>. To expire 
a specific session parameter immediately, call C<clear()> on that parameter.

=item C<remote_addr()>

returns the remote address of the user who created the session for the
first time. Returns undef if variable REMOTE_ADDR wasn't present in the
environment when the session was created

=item C<delete()>

deletes the session from the disk. In other words, it calls for
immediate expiration after which the session will not be accessible

=item C<error()>

returns the last error message from the library. It's the same as the
value of $CGI::Session::errstr. Example:

    $session->flush() or die $session->error();

=item C<dump()>

=item C<dump("file.txt")>

=item C<dump("file.txt", 1)>

=item C<dump("file.txt", 1, 2)>

creates a dump of the session object. The first argument, if passed,
will be interperated as the name of the file dump should be written into.
The second argument, if true, creates a dump of only the B<_DATA> table.
This table contains only the session data that is stored in to the file.
Otherwise, dump() will return the whole objecet dump, including object's
run time attributes, in addition to B<_DATA> table.

The third argument can be between 0 to 3. It denotes what indentation to use
for the dump. Default is 2.

=item C<header()>

header() is simply a replacement for L<CGI.pm|CGI>'s header() method. Without this 
method, you usually need to create a CGI::Cookie object and send it as part of the 
HTTP header:

    $cookie = new CGI::Cookie(-name=>'CGISESSID', -value=>$session->id);
    print $cgi->header(-cookie=>$cookie);

You can minimize the above into:

    $session->header()

It will retrieve the name of the session cookie from $CGI::Session::NAME variable, 
which can also be accessed via CGI::Session->name() method. If you want to use a 
different name for your session cookie, do something like following before 
creating session object:

    CGI::Session->name("MY_SID");
    $session = new CGI::Session(undef, $cgi, \%attrs);

Now, $session->header() uses "MY_SID" as a name for the session cookie.

=item C<cache()>

a way of caching certain values in session object during the process.
This is normally used exclusively from within CGI::Session drivers to
pass certain values from a method to another. It used to be done by setting
a new object attribute from within the driver like so:

    $self->{MYSQL_DBH} = $dbh;

It would cause attribute collisions between the base class and session
driver. cache() method prevents against such unpleasant surprises:

    $self->cache(DBH => $dbh);

=item trace()

Note: this is an experimental feature

Turns debugging mode on. Expects two arguments; the first is a boolean
value indicating if debugging mode is on or off. Default is 0, which denotes
off. The second argument is the path to a file trace/debugging messages
should be written into:

    $session->trace(1, "logs/trace.log");

=item tracemsg()

Note: this is an experimental feature

If, for any reason, you want to write your own message into the trace file,
this is the message you need. Expects a single argument, message to be logged:

    $self->tracemsg("Initializing the old session");

=back

=head1 TIE INTERFACE

In addition to the above described Object Oriented, method-call interface,
CGI::Session supports Apache::Session-like tie() interface as well.
According to this syntax, you first tie() a hash variable with the
library, and use that hash to read and write session data to it.
After tying the hash, that hash becomes a magick variable, and each
your action on that hash triggers disk access accordingly:

    tie %session, "CGI::Session", undef, undef, {Directory=>"/tmp"};

After tying the above %session hash to "CGI::Session", we can now
use it as an ordinary Perl's built-in hash, and guaranteed that Perl
tranparently will be calling respective syntaxes of CGI::Session->param()
as we do

Here are some other operation in the above two syntaxes (OO vs TIE):

=head2 READING FROM THE SESSION

Simply read the key from the %session hash:

    print qq~Hello <a href="mailto:$session{email}">$session{name}</a>~;

=head2 STORING IN THE SESSION

    # In OO:
    $session->param(name=>"Sherzod Ruzmetov",
                    email => 'sherzodr@cpan.org');

    # In tie:
    $session{name} = "Sherzod Ruzmetov";
    $session{email} = 'sherzodr@cpan.org';

=head2 CLEARING CERTAIN SESSION PARAMETERS:

    # In OO:
    $session->clear(["some_param"])

    # In tie:
    delete $session{some_param}

=head2 CLEARING ALL THE SESSION PARAMETERS:

    # In OO:
    $session->clear()

    # In tie:
    %session = ();

=head2 TO DELETE THE SESSION:

    # In OO:
    $session->delete();

    # In tie:
    tied(%session)->delete();

=head2 TO SET EXPIRATION ON SESSION

    # In OO:
    $session->expire("+10m");
    $session->expire(_logged_in=>"+10h");

    # In tie:
    tied(%session)->expire("+10m");
    tied(%session)->expire(_logged_in=>"+10h");

=head2 TO GET SESSION ID

    # In OO:
    $session->id()

    # In tie:
    $session{_SESSION_ID}

For more information on getting the session's private records
such as session id, last access time, remote_addr and such, refer
to the next section L<DATA TABLE>.

=head2 SAVING CGI PARAMETERS

    # In OO:
    $session->save_param($cgi);

    # In tie:
    tied(%session)->save_param($cgi);

=head2 TIE VS. OO INTERFACE. WHICH ONE IS BETTER?

We, definitely, prefer Object Oriented interface for it offers
more features. Besides, TIE interface of the library uses this
interface as well. But again, it's the matter of preference. 
Play around with both syntaxes, and find out for yourself
which one you may prefer. 

You can still have access to CGI::Session's OO methods
through the built-in tied() function. Simply pass the
tied hash to tied(), and it will return the CGI::Session
object you can use to call the methods you need, such as,
"load_param()":

  tied(%session)->load_param($cgi)

=head1 DATA TABLE

Session data is stored in the form of hash table, in key value pairs.
All the parameter names you assign through param() method become keys
in the table, and whatever value you assign become a value associated with
that key. Every key/value pair is also called a record.

All the data you save through param() method are called public records.
These records are both readable and writable by the programmer implementing
the library. There are several read-only private records as well. 
Normally, you don't have to know anything about them to make the best use 
of the library. But knowing wouldn't hurt either. Here are the list of the 
private records and some description  of what they hold:

=over 4

=item _SESSION_ID

Session id of that data. Accessible through id() method.

=item _SESSION_CTIME

Session creation time. Accessible through ctime() method.

=item _SESSION_ATIME

Session last access time. Accessible through atime() method.

=item _SESSION_ETIME

Session's expiration time, if any. Accessible through expire() method.

=item _SESSION_REMOTE_ADDR

IP address of the user who create that session. Accessible through remote_addr()
method

=item _SESSION_EXPIRE_LIST

Another internal hash table that holds the expiration information for each
expirable public record, if any. This table is updated with the two-argument-syntax 
of expires() method.

=back

These private methods are essential for the proper operation of the library
while working with session data. For this purpose, CGI::Session doesn't allow
overriding any of these methods through the use of param() method. In addition,
it doesn't allow any parameter names that start with string B<_SESSION_> either
to prevent future collisions.

So the following attempt will have no effect on the session data whatsoever

    $session->param(_SESSION_XYZ => 'xyz');

Although private methods are not writable, the library allows reading them
using param() method:

    my $sid = $session->param('_SESSION_ID');

The above is the same as:

    my $sid = $session->id();

But we discourage people from accessing private records using param() method.
In the future we are planning to store private records in their own namespace
to avoid name collisions and remove restrictions on session parameter names.

=head1 DISTRIBUTION

CGI::Session consists of several modular components such as L<drivers|"DRIVERS">, 
L<serializers|"SERIALIZERS"> and L<id generators|"ID Generators">. This section 
lists what is available.

=head2 DRIVERS

Following drivers are included in the standard distribution:

=over 4

=item *

L<File|CGI::Session::File> - default driver for storing session data in plain files. 
Full name: B<CGI::Session::File>

=item *

L<DB_File|CGI::Session::DB_File> - for storing session data in BerkelyDB. 
Requires: L<DB_File>. Full name: B<CGI::Session::DB_File>

=item *

L<MySQL|CGI::Session::MySQL> - for storing session data in MySQL tables. 
Requires L<DBI|DBI> and L<DBD::mysql|DBD::mysql>. Full name: B<CGI::Session::MySQL>

=back

=head2 SERIALIZERS

=over 4

=item *

L<Default|CGI::Session::Serialize::Default> - default data serializer. 
Uses standard L<Data::Dumper|Data::Dumper>. Full name: B<CGI::Session::Serialize::Default>.

=item *

L<Storable|CGI::Session::Serialize::Storable> - serializes data using L<Storable>. 
Requires L<Storable>. Full name: B<CGI::Session::Serialize::Storable>.

=item *

L<FreezeThaw|CGI::Session::Serialize::FreezeThaw> - serializes data using L<FreezeThaw>. 
Requires L<FreezeThaw>. Full name: B<CGI::Session::Serialize::FreezeThaw>

=back

=head2 ID GENERATORS

Following ID generators are available:

=over 4

=item *

L<MD5|CGI::Session::ID::MD5> - generates 32 character long hexidecimal string.
Requires L<Digest::MD5|Digest::MD5>. Full name: B<CGI::Session::ID::MD5>.

=item *

L<Incr|CGI::Session::ID::Incr> - generates auto-incrementing ids. Full name: B<CGI::Session::ID::Incr>

=item *

L<Static|CGI::Session::ID::Static> - generates static, session ids. B<CGI::Session::ID::Static>


=back

=head1 CREDITS

Following people contributed with their patches and/or suggestions to 
the development of CGI::Session. Names are in chronological order:

=over 4

=item Andy Lester E<lt>alester@flr.follett.comE<gt>

=item Brian King E<lt>mrbbking@mac.comE<gt>

=item Olivier Dragon E<lt>dragon@shadnet.shad.caE<gt>

=item Adam Jacob E<lt>adam@sysadminsith.orgE<gt>

=item Igor Plisco E<lt>igor@plisco.ruE<gt>

=back


=head1 COPYRIGHT

Copyright (C) 2001, 2002 Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt>. 
All rights reserved.

This library is free software. You can modify and or distribute it under 
the same terms as Perl itself.

=head1 AUTHOR

Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt>. Feedbacks, suggestions are welcome.

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut

# dump() - dumps the session object using Data::Dumper.
sub dump {
    my ($self, $file, $data_only, $indent) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = $indent || 2;

    my $ds = $data_only ? $self->{_DATA} : $self;

    my $d = new Data::Dumper([$ds], [ref($self) . "_dump"]);

    if ( defined $file ) {
        unless ( open(FH, '<' . $file) ) {
            unless(open(FH, '>' . $file)) {
                $self->error("Couldn't open $file: $!");
                return undef;
            }
            print FH $d->Dump();
            unless ( CORE::close(FH) ) {
                $self->error("Couldn't dump into $file: $!");
                return undef;
            }
        }
    }
    return $d->Dump();
}



sub version {   return $VERSION()   }




# save_param() - copies a list of third party object parameters
# into CGI::Session object's '_DATA' table
sub save_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess "save_param(): first argument should be an object";

    }
    unless ( $cgi->can('param') ) {
        confess "save_param(): Cannot call method param() on the object";
    }

    my @params = ();
    if ( defined $list ) {
        unless ( ref($list) eq 'ARRAY' ) {
            confess "save_param(): second argument must be an arrayref";
        }

        @params = @{ $list };

    } else {
        @params = $cgi->param();

    }

    my $n = 0;
    for ( @params ) {
        # It's imporatnt to note that CGI.pm's param() returns array
        # if a parameter has more values associated with it (checkboxes
        # and crolling lists). So we should access its parameters in
        # array context not to miss anything
        my @values = $cgi->param($_);

        if ( defined $values[1] ) {
            $self->_set_param($_ => \@values);

        } else {
            $self->_set_param($_ => $values[0] );

        }

        ++$n;
    }

    return $n;
}


# load_param() - loads a list of third party object parameters
# such as CGI, into CGI::Session's '_DATA' table
sub load_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess "save_param(): first argument must be an object";

    }
    unless ( $cgi->can('param') ) {
        my $class = ref($cgi);
        confess "save_param(): Cannot call method param() on the object $class";
    }

    my @params = ();
    if ( defined $list ) {
        unless ( ref($list) eq 'ARRAY' ) {
            confess "save_param(): second argument must be an arrayref";
        }
        @params = @{ $list };

    } else {
        @params = $self->param();

    }

    my $n = 0;
    for ( @params ) {
        $cgi->param(-name=>$_, -value=>$self->_get_param($_));
    }
    return $n;
}




# another, but a less efficient alternative to undefining
# the object
sub close {
    my $self = shift;

    $self->DESTROY();
}



# error() returns/sets error message
sub error {
    my ($self, $msg) = @_;

    if ( defined $msg ) {
        $errstr = $msg;
    }

    return $errstr;
}


# errstr() - alias to error()
sub errstr {
    my $self = shift;

    return $self->error(@_);
}



# atime() - rerturns session last access time
sub atime {
    my $self = shift;

    if ( @_ ) {
        confess "_SESSION_ATIME - read-only value";
    }

    return $self->{_DATA}->{_SESSION_ATIME};
}


# ctime() - returns session creation time
sub ctime {
    my $self = shift;

    if ( defined @_ ) {
        confess "_SESSION_ATIME - read-only value";
    }

    return $self->{_DATA}->{_SESSION_CTIME};
}


# expire() - sets/returns session/parameter expiration ticker
sub expire {
    my $self = shift;

    unless ( @_ ) {
        return $self->{_DATA}->{_SESSION_ETIME};
    }

    if ( @_ == 1 ) {
        return $self->{_DATA}->{_SESSION_ETIME} = _time_alias( $_[0] );
    }

    # If we came this far, we'll simply assume user is trying
    # to set an expiration date for a single session parameter.
    my ($param, $etime) = @_;

    # Let's check if that particular session parameter exists
    # in the '_DATA' table. Otherwise, return now!
    defined ($self->{_DATA}->{$param} ) || return;

    if ( $etime eq '-1' ) {
        delete $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$param};
        return;
    }

    $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{$param} = _time_alias( $etime );
}


# expires() - alias to expire(). For backward compatibility with older releases.
sub expires {
    return expire(@_);
}


# parses such strings as '+1M', '+3w', accepted by expire()
sub _time_alias {
    my ($str) = @_;

    # If $str consists of just digits, return them as they are
    if ( $str =~ m/^\d+$/ ) {
        return $str;
    }

    my %time_map = (
        s           => 1,
        m           => 60,
        h           => 3600,
        d           => 86400,
        w           => 604800,
        M           => 2592000,
        y           => 31536000
    );

    my ($koef, $d) = $str =~ m/^([+-]?\d+)(\w)$/;

    if ( defined($koef) && defined($d) ) {
        return $koef * $time_map{$d};
    }
}


# remote_addr() - returns ip address of the session
sub remote_addr {
    my $self = shift;

    return $self->{_DATA}->{_SESSION_REMOTE_ADDR};
}


# param_hashref() - returns parameters as a reference to a hash
sub param_hashref {
    my $self = shift;

    return $self->{_DATA};
}


# name() - returns the cookie name associated with the session id
sub name {
    my ($class, $name)  = @_;

    if ( defined $name ) {
        $CGI::Session::NAME = $name;
    }

    return $CGI::Session::NAME;
}


# header() - replacement for CGI::header() method
sub header {
    my $self = shift;

    my $cgi = $self->{_SESSION_OBJ};
    unless ( defined $cgi ) {
        require CGI;
        $self->{_SESSION_OBJ} = CGI->new();
        return $self->header();
    }

    my $cookie = $cgi->cookie($self->name(), $self->id() );

    return $cgi->header(
        -type   => 'text/html',
        -cookie => $cookie,
        @_
    );
}


# sync_param() - synchronizes CGI and Session parameters.
sub sync_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess("$cgi doesn't look like an object");
    }

    unless ( $cgi->UNIVERSAL::can('param') ) {
        confess(ref($cgi) . " doesn't support param() method");
    }

    # we first need to save all the available CGI parameters to the
    # object
    $self->save_param($cgi, $list);

    # we now need to load all the parameters back to the CGI object
    return $self->load_param($cgi, $list);
}





# cache() - used by driver authors to cache certain values in the
# object. Use of this method is prefered over accessing $self hashref
# directly to avoid future namespace collisions. Experimental!
sub cache {
    my $self = shift;

    unless ( @_ ) {
        croak "cache(): arguments missing";
    }

    if ( scalar(@_) == 1 ) {
        return $self->{_CACHE}->{ $_[0] };
    }

    if ( @_ % 2 ) {
        croak "cache(): invalid number of arguments";
    }

    my %args = @_;
    my $n    = 0;
    while ( my ($k, $v) = each %args ) {
        $self->{_CACHE}->{$k} = $v;
        $n++;
    }

    return $n;
}






# trace() - to debug the libarary.
sub trace {
    my ($self, $bool, $file) = @_;

    $self->{_TRACE_MODE} = $bool;
    $self->{_TRACE_FILE} = $file;

    open(TRACE, ">>" . $file) or croak $!;
    $self->{_TRACE_FH} = \*TRACE;

    return 1;
}






# tracemsg() - logs a message in a trace log
sub tracemsg {
    my ($self, $msg) = @_;

    unless ( $self->{_TRACE_MODE} ) {
        return;
    }

    my $fh = $self->{_TRACE_FH} or croak "'_TRACE_FH' is not defined";
    print $fh $msg, "\n";
}



#--------------------------------------------------------------------
# tie() interface - EXPERIMENTAL!
#--------------------------------------------------------------------

sub TIEHASH {
    my $class = shift;
    return $class->new(@_);
}


sub FETCH {
    my ($self, $param) = @_;
    return $self->param(-name=>$param);
}



sub STORE {
    my ($self, $param, $value) = @_;
    return $self->param(-name=>$param, -value=>$value);
}



# This does NOT implement delete(), but clear() instead
sub DELETE {
    my ($self, $param) = @_;
    return $self->clear([$param]);
}


# This does implement clear, but with no arguments
sub CLEAR {
    my $self = shift;
    return $self->clear();
}


sub EXISTS {
    my ($self, $param) = @_;
    return $self->param($param);
}


sub FIRSTKEY {
    my $self = shift;
    my $temp = keys %{$self->{_DATA}};
    return scalar each %{$self->{_DATA}};
}



sub NEXTKEY {
    my $self = shift;
    return scalar each %{$self->{_DATA}};
}

# $Id$
