package CGI::Session;

# $Id$

use strict;
use Carp;
use CGI::Session::ErrorHandler;

use vars qw( @ISA );

@ISA = qw( CGI::Session::ErrorHandler );

$CGI::Session::VERSION    = '3.91';
$CGI::Session::NAME       = 'CGISESSID';

sub STATUS_NEW      () { 1 }        # denotes session that's just created
sub STATUS_MODIFIED () { 2 }        # denotes session that's needs synchronization
sub STATUS_DELETED  () { 4 }        # denotes session that needs deletion
sub STATUS_EXPIRED  () { 8 }        # denotes session that was expired. 


sub new {
    my $class = shift;

    my $self = undef;
    if ( (@_ == 1) && ref( $_[0] ) && $_[0]->isa($class) ) {
        $self = shift;
    } else {
        defined($self = $class->instance( @_ )) or return;
    }
    
    $self->_reset_status();         # <-- we do not want status information passing to the new object
                                    # since it would confuse everyone

    if ( $self->empty ) {
        $self->{_DATA}->{_SESSION_ID} = $self->_id_generator()->generate_id($self->{_DRIVER_ARGS}, $self->{_CLAIMED_ID});
        unless ( defined $self->{_DATA}->{_SESSION_ID} ) {
            return $self->error( "Couldn't generate new SID" );
        }
        $self->_set_status(STATUS_NEW);
    }
    return $self;
}


sub instance {
    my $class = shift;

    return $class->error( "new(): called as instance method")    if ref $class;
    return $class->error( "new(): invalid number of arguments")  if @_ > 3;

    my $self = bless {
        _DATA       => {
            _SESSION_ID     => undef,
            _SESSION_CTIME  => time(),
            _SESSION_ATIME  => undef,
            _SESSION_ETIME  => undef,
            _SESSION_REMOTE_ADDR => $ENV{REMOTE_ADDR} || "",
            _SESSION_EXPIRE_LIST => {}
        },          # session data
        _DSN        => {},          # parsed DSN params
        _OBJECTS    => {},          # keeps necessary objects
        _DRIVER_ARGS=> {},          # arguments to be passed to driver
        _CLAIMED_ID => undef,       # id **claimed** by client
        _STATUS     => 0,           # status of the session object
        _QUERY      => undef,       # query object
        _errstr     => "",
    }, $class;

    if ( @_ == 1 ) {
        if ( ref $_[0] ){ $self->{_QUERY}       = $_[0]  }
        else            { $self->{_CLAIMED_ID}  = $_[0]  }
    }

    # Two or more args passed:
    if ( @_ > 1 ) {
        if ( defined $_[0] ) {      # <-- to avoid 'Uninitialized value...' carpings
            %{ $self->{_DSN} } = map { split /:/ } split /;/, $_[0];
            # 
            # convertingn all the values to lowercase
            while ( my($key, $value) = each %{ $self->{_DSN} } ) {
                $self->{_DSN}->{$key} = lc $value;
            }
        }
        #
        # second argument can either be $sid, or  $query
        if ( ref $_[1] ){ $self->{_QUERY}       = $_[1] }
        else            { $self->{_CLAIMED_ID}  = $_[1] }
    }

    #
    # grabbing the 3rd argument, if any
    if ( @_ == 3 ){ $self->{_DRIVER_ARGS} = $_[2] }

    #
    # setting defaults, since above arguments might be 'undef'
    $self->{_DSN}->{driver}     ||= "file";
    $self->{_DSN}->{serializer} ||= "default";
    $self->{_DSN}->{id}         ||= "md5";

    #
    unless ( $self->{_CLAIMED_ID} ) {
        my $query = $self->query();
        eval {
            $self->{_CLAIMED_ID} = $query->cookie( $self->name ) || $query->param( $self->name );
        };
        if ( my $errmsg = $@ ) {
            return $class->error( "couldn't acquire: " .  $errmsg );
        }
    }
    return $self->init ? $self : undef;
}


sub init {
    my $self = shift;

    my @pms = ();
    $pms[0] = "CGI::Session::Driver::"      . $self->{_DSN}->{driver};
    $pms[1] = "CGI::Session::Serialize::"  . $self->{_DSN}->{serializer};
    $pms[2] = "CGI::Session::ID::"          . $self->{_DSN}->{id};

    for ( @pms ) {
        eval "require $_";
        if ( my $errmsg = $@ ) {
            return $self->error("couldn't load $_: " . $errmsg);
        }
    }

    #
    # Creating & caching driver object
    defined($self->{_OBJECTS}->{driver} = $pms[0]->new( $self->{_DRIVER_ARGS} ) )
        or return $self->error( "init(): couldn't create driver object: " .  $pms[0]->errstr );

    $self->{_OBJECTS}->{serializer} = $pms[1];
    $self->{_OBJECTS}->{id}         = $pms[2];

    return 1 unless  $self->{_CLAIMED_ID};
    
    my $raw_data = $self->{_OBJECTS}->{driver}->retrieve( $self->{_CLAIMED_ID} );
    unless ( defined $raw_data ) {
        return $self->error( "init(): couldn't retireve data: " . $self->{_OBJECTS}->{driver}->errstr );
    }
    unless ( $raw_data ) {                              # <-- such session doesn't exist in storage
        return 1;
    }

    $self->{_DATA} = $self->{_OBJECTS}->{serializer}->thaw($raw_data);
    unless ( defined $self->{_DATA} ) {
        return $self->error( $self->{_OBJECTS}->{serializer}->errstr );
    }
    unless ( ref ($self->{_DATA}) && (ref $self->{_DATA} eq 'HASH') ) {
        return $self->error( "Invalid data structure returned from thaw()" );
    }    
    # checking for expiration ticker
    if ( $self->{_SESSION_ETIME} ) {
        if ( ($self->{_SESSION_ATIME} + $self->{_SESSION_ETIME}) >= time() ) {
            $self->{_DATA} = {};                    # <-- resetting expired session data
            $self->_set_status( STATUS_EXPIRED );   # <-- so client can detect expired sessions
            $self->_set_status( STATUS_DELETED );   # <-- session should be removed from database
            return 1;
        }
    }

    # checking expiration tickers of individuals parameters, if any:
    my @expired_params = ();
    while (my ($param, $etime) = each %{ $self->{_DATA}->{_SESSION_EXPIRE_LIST} } ) {
        if ( ($self->{_SESSION_ATIME} + $etime) >= time() ) {
            push @expired_params, $param;
        }
    }
    $self->clear(\@expired_params) if @expired_params;
    $self->{_DATA}->{_SESSION_ATIME} = time();      # <-- updating access time
    $self->_set_status( STATUS_MODIFIED );          # <-- access time modified above

    return 1;
}


sub DESTROY         {   $_[0]->flush()  }

*param_hashref      = \&dataref;
sub dataref         { $_[0]->{_DATA}    }
sub empty           { !$_[0]->id        }
sub expired         { $_[0]->_test_status( STATUS_EXPIRED ) }
#sub error           { croak $_[1]       }
sub id              { $_[0]->dataref->{_SESSION_ID}     }
sub atime           { $_[0]->dataref->{_SESSION_ATIME}  }
sub ctime           { $_[0]->dataref->{_SESSION_CTIME}  }
sub etime           { $_[0]->dataref->{_SESSION_ETIME}  }

sub _driver         { $_[0]->{_OBJECTS}->{driver} }
sub _serializer     { $_[0]->{_OBJECTS}->{serializer} }
sub _id_generator   { $_[0]->{_OBJECTS}->{id} }


sub query {
    my $self = shift;

    if ( $self->{_QUERY} ) {
        return $self->{_QUERY};
    }
    require CGI;
    $self->{_QUERY} = CGI->new();
    return $self->{_QUERY};
}


sub name {
    unless ( defined $_[1] ) {
        return $CGI::Session::NAME;
    }
    $CGI::Session::NAME = $_[1];
}


sub dump {
    my $self = shift;

    require Data::Dumper;
    my $d = Data::Dumper->new([$self], [ref $self]);
    return $d->Dump();
}


sub _set_status {
    my $self    = shift;
    croak "_set_status(): usage error" unless @_;
    $self->{_STATUS} |= $_ for @_;
}


sub _unset_status {
    my $self = shift;
    croak "_unset_status(): usage error" unless @_;
    $self->{_STATUS} &= ~$_ for @_;
}


sub _reset_status {
    $_[0]->{_STATUS} = 0;
}

sub _test_status {
    return $_[0]->{_STATUS} & $_[1];
}


sub flush {
    my $self = shift;

    return unless $self->id;            # <-- empty session
    return if $self->{_STATUS} == 0;    # <-- neither new, nor deleted nor modified

    if ( $self->_test_status(STATUS_NEW) && $self->_test_status(STATUS_DELETED) ) {
        return $self->_reset_status();
    }
    
    my $driver      = $self->_driver();
    my $serializer  = $self->_serializer();

    if ( $self->_test_status(STATUS_DELETED) ) {
        defined($driver->remove($self->id)) or
            return $self->error( "flush(): couldn't remove session data: " . $driver->errstr );
        return $self->_reset_status();
    }

    if ( $self->_test_status(STATUS_NEW) || $self->_test_status(STATUS_MODIFIED) ) {
        my $datastr = $serializer->freeze( $self->dataref );
        unless ( defined $datastr ) {
            return $self->error( "flush(): couldn't freeze data: " . $serializer->errstr );
        }
        defined( $driver->store($self->id, $datastr) ) or
            return $self->error( "flush(): couldn't store datastr: " . $driver->errstr);
        $self->_reset_status();
    }
    return 1;
}


*expires = \&expire;
sub expire {
    my $self = shift;

    return $self->{_DATA}->{_SESSION_ETIME} unless @_;
    if ( @_ == 1 ) {
        if ( ($_[0] =~ m/^\d$/) && ($_[0] == 0) ) {
            $self->{_DATA}->{_SESSION_ETIME} = undef;
        } else {
            $self->{_DATA}->{_SESSION_ETIME} = $self->_str2seconds( $_[0] );
        }
        return 1;
    }

    if ( ($_[1] =~ m/^\d$/) && ($_[1] == 0) ) {
        delete $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{ $_[0] };
    } else {
        $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{ $_[0] } = $self->_str2seconds( $_[1] );
    }
}


sub trace {}
sub tracemsg {}

sub _str2seconds {
    my $self = shift;
    my ($str) = @_;

    return unless defined $str;
    return $str if $str =~ m/^\d+$/;

    my %_map = (
        s       => 1,
        m       => 60,
        h       => 3600,
        d       => 86400,
        w       => 604800,
        M       => 2592000,
        y       => 31536000
    );

    my ($koef, $d) = $str =~ m/^([+-]?\d+)([smhdwMy])$/;
    unless ( defined($koef) && defined($d) ) {
        die "_str2seconds(): couldn't parse $str into \$koef and \$d parts. Possible invalid syntax";
    }
    return $koef * $_map{ $d };
}













sub param {
    my $self = shift;

    carp "param(): attempt to read/write deleted session" if $self->_test_status(STATUS_DELETED);

    my $dataref = $self->dataref();

    return keys %$dataref unless @_;
    return $dataref->{$_[0]} if @_ == 1;

    my %args = (
        -name   => undef,
        -value  => undef,
        @_
    );

    if ( defined( $args{'-name'} ) && defined( $args{'-value'} ) ) {
        $self->_set_status(STATUS_MODIFIED);
        return $dataref->{ $args{'-name'} } = $args{'-value'};
    }

    if ( defined $args{'-name'} ) {
        return $dataref->{ $args{'-name'} };
    }

    if ( @_ == 2 ) {
        $self->_set_status(STATUS_MODIFIED);
        return $dataref->{ $_[0] } = $_[1];
    }

    unless ( @_ % 2 ) {
        for ( my $i=0; $i < @_; $i += 2 ) {
            $dataref->{ $_[$i] } = $_[$i+1];
        }
        return $self->_set_status(STATUS_MODIFIED);
    }
    croak "param(): usage error";
}



sub delete {    $_[0]->_set_status( STATUS_DELETED )    }


*header = \&http_header;
sub http_header {
    my $self = shift;

    my $query = $self->query();
    my $cookie = $query->cookie( -name => $self->name, -value => $self->id );
    return $query->header(-cookie=>$cookie, type=>'text/html', @_);
}



sub save_param {
    my $self = shift;
    my ($query, $params) = @_;

    $query ||= $self->query();
    $params ||= [ $query->param ];

    for ( @$params ) {
        $self->param($_, $query->param($_));
    }
    $self->_set_status( STATUS_MODIFIED );
}



sub load_param {
    my $self = shift;
    my ($query, $params) = @_;

    $query ||= $self->query();
    $params ||= [ $self->param ];

    for ( @$params ) {
        $query->param($_, $self->param($_));
    }
}


sub clear {
    my $self = shift;
    my ($params) = @_;
    
    $params ||= [ $self->param ];
    my $dataref = $self->dataref();
    
    for ( @$params ) {
        delete $dataref->{ $_ };
    }
    $self->_set_status( STATUS_MODIFIED );
}





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
