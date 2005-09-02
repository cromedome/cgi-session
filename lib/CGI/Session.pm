package CGI::Session;

# $Id$

use strict;
use Carp;
use CGI::Session::ErrorHandler;

@CGI::Session::ISA      = qw( CGI::Session::ErrorHandler );
$CGI::Session::VERSION  = '4.02';
$CGI::Session::NAME     = 'CGISESSID';
$CGI::Session::IP_MATCH = 0;

sub STATUS_NEW      () { 1 }        # denotes session that's just created
sub STATUS_MODIFIED () { 2 }        # denotes session that needs synchronization
sub STATUS_DELETED  () { 4 }        # denotes session that needs deletion
sub STATUS_EXPIRED  () { 8 }        # denotes session that was expired.

sub import {
    my $class = shift;
    @_ or return;

    for(@_) {
        $CGI::Session::IP_MATCH = ( $_ eq '-ip_match' );
    }
}

sub new {
    my $class   = shift;

    # If called as object method as in $session->new()...
    my $self;
    if ( ref $class ) {
        $self   = bless { %$class }, ref($class);
        $class  = ref($class);
        $self->_reset_status();

        # Object may still have public data associated with it, but we don't care about that,
        # since we want to leave that to the client's disposal. However, if new() was requested on
        # an expired session, we already know that '_DATA' table is empty, since it was the
        # job of flush() to empty '_DATA' after deleting. How do we know flush() was already
        # called on an expired session? Because load() - constructor always calls flush()
        # on all to-be expired sessions
    } else {
        defined($self = $class->load( @_ ))
            or return $class->set_error( "new(): failed: " . $class->errstr );
    }

    # Absence of '_SESSION_ID' can only signal:
    #   * expired session
    #       Because load() - constructor is required to empty contents of _DATA - table
    #   * unavailable session
    #       Such sessions are the ones that don't exist on datastore, but requested by client
    #   * new sessions
    #       When no specific session is requested to be loaded
    unless ( $self->{_DATA}->{_SESSION_ID} ) {
        $self->{_DATA}->{_SESSION_ID} = $self->_id_generator()->generate_id($self->{_DRIVER_ARGS}, $self->{_CLAIMED_ID});
        unless ( defined $self->{_DATA}->{_SESSION_ID} ) {
            return $self->set_error( "Couldn't generate new SID" );
        }
        $self->{_DATA}->{_SESSION_CTIME} = $self->{_DATA}->{_SESSION_ATIME} = time();
        $self->_set_status(STATUS_NEW);
    }
    return $self;
}

sub DESTROY         {   $_[0]->flush()      }
sub close           {   $_[0]->flush()      }

*param_hashref      = \&dataref;
my $avoid_single_use_warning = *param_hashref;
sub dataref         { $_[0]->{_DATA}        }

sub is_empty        { !defined($_[0]->id)   }

sub is_expired      { $_[0]->_test_status( STATUS_EXPIRED ) }

sub is_new          { $_[0]->_test_status( STATUS_NEW ) }

sub id              { return defined($_[0]->dataref) ? $_[0]->dataref->{_SESSION_ID}    : undef }

sub atime           { return defined($_[0]->dataref) ? $_[0]->dataref->{_SESSION_ATIME} : undef }

sub ctime           { return defined($_[0]->dataref) ? $_[0]->dataref->{_SESSION_CTIME} : undef }

sub _driver         { $_[0]->{_OBJECTS}->{driver} }

sub _serializer     { $_[0]->{_OBJECTS}->{serializer} }

sub _id_generator   { $_[0]->{_OBJECTS}->{id} }

sub _ip_matches {
  return ( $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR} eq $ENV{REMOTE_ADDR} );
}


# parses the DSN string and returns it as a hash.
# Notably: Allows unique abbreviations of the keys: driver, serializer and 'id'.
# Also, keys and values of the returned hash are lower-cased.
sub parse_dsn {
    my $self = shift;
    my $dsn_str = shift;
    croak "parse_dsn(): usage error" unless $dsn_str;

    require Text::Abbrev;
    my $abbrev = Text::Abbrev::abbrev( "driver", "serializer", "id" );
    my %dsn_map = map { split /:/ } (split /;/, $dsn_str);
    my %dsn  = map { $abbrev->{lc $_}, lc $dsn_map{$_} } keys %dsn_map;
    return \%dsn;
}

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
    $d->Deepcopy(1);
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
        $self->{_DATA} = {};
        return $self->_unset_status(STATUS_NEW, STATUS_DELETED);
    }

    my $driver      = $self->_driver();
    my $serializer  = $self->_serializer();

    if ( $self->_test_status(STATUS_DELETED) ) {
        defined($driver->remove($self->id)) or
            return $self->set_error( "flush(): couldn't remove session data: " . $driver->errstr );
        $self->{_DATA} = {};                        # <-- removing all the data, making sure
                                                    # it won't be accessible after flush()
        return $self->_unset_status(STATUS_DELETED);
    }

    if ( $self->_test_status(STATUS_NEW) || $self->_test_status(STATUS_MODIFIED) ) {
        my $datastr = $serializer->freeze( $self->dataref );
        unless ( defined $datastr ) {
            return $self->set_error( "flush(): couldn't freeze data: " . $serializer->errstr );
        }
        defined( $driver->store($self->id, $datastr) ) or
            return $self->set_error( "flush(): couldn't store datastr: " . $driver->errstr);
        $self->_unset_status(STATUS_NEW, STATUS_MODIFIED);
    }
    return 1;
}

sub trace {}
sub tracemsg {}

sub param {
    my $self = shift;

    carp "param(): attempt to read/write deleted session" if $self->_test_status(STATUS_DELETED);

    #
    # USAGE: $s->param();
    # DESC: returns all the **public** parameters
    unless ( @_ ) {
        return grep { !/^_SESSION_/ } keys %{ $self->{_DATA} };
    }

    #
    # USAGE: $s->param($p);
    # DESC: returns a specific session parameter
    return $self->{_DATA}->{$_[0]} if @_ == 1;

    my %args = (
        -name   => undef,
        -value  => undef,
        @_
    );

    #
    # USAGE: $s->param(-name=>$n, -value=>$v);
    # DESC:  updates session data using CGI.pm's 'named parameter' syntax. Only
    # public records can be set!
    if ( defined( $args{'-name'} ) && defined( $args{'-value'} ) ) {
        if ( $args{'-name'} =~ m/^_SESSION_/ ) {
            carp "param(): attempt to write to private parameter";
            return undef;
        }
        $self->_set_status(STATUS_MODIFIED);
        return $self->{_DATA}->{ $args{'-name'} } = $args{'-value'};
    }

    #
    # USAGE: $s->param(-name=>$n);
    # DESC:  access to session data (public & private) using CGI.pm's 'named parameter' syntax.
    return $self->{_DATA}->{ $args{'-name'} } if defined $args{'-name'};

    # USAGE: $s->param($name, $value);
    # USAGE: $s->param($name1 => $value1, $name2 => $value2 [,...]);
    # DESC:  updates one or more **public** records using simple syntax
    unless ( @_ % 2 ) {
        for ( my $i=0; $i < @_; $i += 2 ) {
            if ( $_[$i] =~ m/^_SESSION_/) {
                carp "param(): attempt to write to private parameter";
                next;
            }
            $self->{_DATA}->{ $_[$i] } = $_[$i+1];
        }
        $self->_set_status(STATUS_MODIFIED);
        return 1;
    }

    #
    # If we reached this far none of the expected syntax were detected. Syntax error
    croak "param(): usage error. Invalid number";
}



sub delete {    $_[0]->_set_status( STATUS_DELETED )    }


*header = \&http_header;
my $avoid_single_use_warning_again = *header;
sub http_header {
    my $self = shift;
    return $self->query->header(-cookie=>$self->cookie, type=>'text/html', @_);
}

sub cookie {
    my $self = shift;

    my $query = $self->query();
    my $cookie= undef;

    if ( $self->is_expired ) {
        $cookie = $query->cookie( -name=>$self->name, -value=>$self->id, -expires=> '-1d', @_ );
    } elsif ( my $t = $self->expire ) {
        $cookie = $query->cookie( -name=>$self->name, -value=>$self->id, -expires=> $t . 's', @_ );
    } else {
        $cookie = $query->cookie( -name=>$self->name, -value=>$self->id, @_ );
    }

    return $cookie;
}





sub save_param {
    my $self = shift;
    my ($query, $params) = @_;

    $query  ||= $self->query();
    $params ||= [ $query->param ];

    for my $p ( @$params ) {
        my @values = $query->param($p) or next;
        if ( @values > 1 ) {
            $self->param($p, \@values);
        } else {
            $self->param($p, $values[0]);
        }
    }
    $self->_set_status( STATUS_MODIFIED );
}



sub load_param {
    my $self = shift;
    my ($query, $params) = @_;

    $query  ||= $self->query();
    $params ||= [ $self->param ];

    for ( @$params ) {
        $query->param(-name=>$_, -value=>$self->param($_));
    }
}


sub clear {
    my $self    = shift;
    my $params  = shift;
    #warn ref($params);
    if (defined $params) {
        $params =  [ $params ] unless ref $params;
    }
    else {
        $params = [ $self->param ];
    }

    for ( @$params ) {
        delete $self->{_DATA}->{$_};
    }
    $self->_set_status( STATUS_MODIFIED );
}


sub find {
    my $class       = shift;
    my ($dsnstr, $coderef, $dsn_args);

    if ( @_ == 1 ) {
        $coderef = $_[0];
    } else {
        ($dsnstr, $coderef, $dsn_args) = @_;
    }

    unless ( $coderef && ref($coderef) && (ref $coderef eq 'CODE') ) {
        croak "find(): usage error.";
    }

    my $driver;
    if ( $dsnstr ) {
        my $hashref = $class->parse_dsn( $dsnstr );
        $driver     = $hashref->{driver};
    }
    $driver ||= "file";
    my $pm = "CGI::Session::Driver::" . $driver;
    eval "require $pm";
    if (my $errmsg = $@ ) {
        return $class->set_error( "find(): couldn't load driver." . $errmsg );
    }

    my $driver_obj = $pm->new( $dsn_args );
    unless ( $driver_obj ) {
        return $class->set_error( "find(): couldn't create driver object. " . $pm->errstr );
    }

    my $driver_coderef = sub {
        my ($sid) = @_;
        my $session = $class->load( $dsnstr, $sid, $dsn_args );
        unless ( $session ) {
            return $class->set_error( "find(): couldn't load session '$sid'. " . $class->errstr );
        }
        $coderef->( $session );
    };

    defined($driver_obj->traverse( $driver_coderef ))
        or return $class->set_error( "find(): traverse seems to have failed. " . $driver_obj->errstr );
    return 1;
}

# $Id$

=pod

=head1 NAME

CGI::Session - persistent session data in CGI applications

=head1 SYNOPSIS

    # Object initialization:
    use CGI::Session;
    $session = new CGI::Session();

    $CGISESSID = $session->id();

    # send proper HTTP header with cookies:
    print $session->header();

    # storing data in the session
    $session->param('f_name', 'Sherzod');
    # or
    $session->param(-name=>'l_name', -value=>'Ruzmetov');

    # retrieving data
    my $f_name = $session->param('f_name');
    # or
    my $l_name = $session->param(-name=>'l_name');

    # clearing a certain session parameter
    $session->clear(["l_name", "f_name"]);

    # expire '_is_logged_in' flag after 10 idle minutes:
    $session->expire('is_logged_in', '+10m')

    # expire the session itself after 1 idle hour
    $session->expire('+1h');

    # delete the session for good
    $session->delete();

=head1 DESCRIPTION

CGI-Session is a Perl5 library that provides an easy, reliable and modular session management system across HTTP requests.
Persistency is a key feature for such applications as shopping carts, login/authentication routines, and application that
need to carry data across HTTP requests. CGI::Session does that and many more.

=head1 TO LEARN MORE

Current manual is optimized to be used as a quick reference. To learn more both about the philosophy and CGI::Session
programming style, consider the following:

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual. Also includes library architecture and driver specifications.

=item *

We also provide mailing lists for CGI::Session users. To subscribe to the list or browse the archives visit https://lists.sourceforge.net/lists/listinfo/cgi-session-user

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session.

=back

=head1 METHODS

Following is the overview of all the available methods accessible via CGI::Session object.

=over 4

=item new()

=item new( $sid )

=item new( $query )

=item new( $dsn, $query||$sid )

=item new( $dsn, $query||$sid, \%dsn_args )

Constructor. Returns new session object, or undef on failure. Error message is accessible through L<errstr() - class method|CGI::Session::ErrorHandler/errstr>. If called on an already initialized session will re-initialize the session based on already configured object. This is only useful after a call to L<load()|/"load">.

Can accept up to three arguments, $dsn - Data Source Name, $query||$sid - query object OR a string representing session id, and finally, \%dsn_args, arguments used by $dsn components.

If called without any arguments, $dsn defaults to I<driver:file;serializer:default;id:md5>, $query||$sid defaults to C<< CGI->new() >>, and C<\%dsn_args> defaults to I<undef>.

If called with a single argument, it will be treated either as C<$query> object, or C<$sid>, depending on its type. If argument is a string , C<new()> will treat it as session id and will attempt to retrieve the session from data store. If it fails, will create a new session id, which will be accessible through L<id() method|/"id">. If argument is an object, L<cookie()|CGI/cookie> and L<param()|CGI/param> methods will be called on that object to recover a potential C<$sid> and retrieve it from data store. If it fails, C<new()> will create a new session id, which will be accessible through L<id() method|/"id">. C<$CGI::Session::NAME> will define the name of the query parameter and/or cookie name to be requested, defaults to I<CGISESSID>.

If called with two arguments first will be treated as $dsn, and second will be treated as $query or $sid or undef, depending on its type. Some examples of this syntax are:

    $s = CGI::Session->new("driver:mysql", undef);
    $s = CGI::Session->new("driver:sqlite", $sid);
    $s = CGI::Session->new("driver:db_file", $query);
    $s = CGI::Session->new("serializer:storable;id:incr", $sid);
    # etc...


Following data source components are supported:

=over 4

=item *

B<driver> - CGI::Session driver. Available drivers are L<file|CGI::Session::Driver::file>, L<db_file|CGI::Session::Driver::db_file>, L<mysql|CGI::Session::Driver::mysql> and L<sqlite|CGI::Session::Driver::sqlite>. Third party drivers are welcome. For driver specs consider L<CGI::Session::Driver|CGI::Session::Driver>

=item *

B<serializer> - serializer to be used to encode the data structure before saving
in the disk. Available serializers are L<storable|CGI::Session::Serialize::storable>, L<freezethaw|CGI::Session::Serialize::freezethaw> and L<default|CGI::Session::Serialize::default>. Default serializer will use L<Data::Dumper|Data::Dumper>.

=item *

B<id> - ID generator to use when new session is to be created. Available ID generator is L<md5|CGI::Session::ID::md5>

=back

For example, to get CGI::Session store its data using DB_File and serialize data using FreezeThaw:

    $s = new CGI::Session("driver:DB_File;serializer:FreezeThaw", undef);

If called with three arguments, first two will be treated as in the previous example, and third argument will be C<\%dsn_args>, which will be passed to C<$dsn> components (namely, driver, serializer and id generators) for initialization purposes. Since all the $dsn components must initialize to some default value, this third argument should not be required for most drivers to operate properly.

undef is acceptable as a valid placeholder to any of the above arguments, which will force default behavior.

=item load()

=item load($query||$sid)

=item load($dsn, $query||$sid)

=item load($dsn, $query, \%dsn_args);

Constructor. Usage is identical to L<new()|/"new">, so is the return value. Major difference is, L<new()|/"new"> can create new session if it detects expired and non-existing sessions, but C<load()> does not.

C<load()> is useful to detect expired or non-existing sessions without forcing the library to create new sessions. So now you can do something like this:

    $s = CGI::Session->load() or die CGI::Session->errstr();
    if ( $s->is_expired ) {
        print $s->header(),
            $cgi->start_html(),
            $cgi->p("Your session timed out! Refresh the screen to start new session!")
            $cgi->end_html();
        exit(0);
    }

    if ( $s->is_empty ) {
        $s = $s->new() or die $s->errstr;
    }

Notice, all I<expired> sessions are empty, but not all I<empty> sessions are expired!

=cut

sub load {
    my $class = shift;

    return $class->set_error( "called as instance method")    if ref $class;
    return $class->set_error( "invalid number of arguments")  if @_ > 3;

    my $self = bless {
        _DATA       => {
            _SESSION_ID     => undef,
            _SESSION_CTIME  => undef,
            _SESSION_ATIME  => undef,
            _SESSION_REMOTE_ADDR => $ENV{REMOTE_ADDR} || "",
            #
            # Following two attributes may not exist in every single session, and declaring
            # them now will force these to get serialized into database, wasting space. But they
            # are here to remind the coder of their purpose
            #
#            _SESSION_ETIME  => undef,
#            _SESSION_EXPIRE_LIST => {}
        },          # session data
        _DSN        => {},          # parsed DSN params
        _OBJECTS    => {},          # keeps necessary objects
        _DRIVER_ARGS=> {},          # arguments to be passed to driver
        _CLAIMED_ID => undef,       # id **claimed** by client
        _STATUS     => 0,           # status of the session object
        _QUERY      => undef        # query object
    }, $class;

    #$self->{_DATA}->{_SESSION_CTIME} = $self->{_DATA}->{_SESSION_ATIME} = time();

    if ( @_ == 1 ) {
        if ( ref $_[0] ){ $self->{_QUERY}       = $_[0]  }
        else            { $self->{_CLAIMED_ID}  = $_[0]  }
    }

    # Two or more args passed:
    if ( @_ > 1 ) {
        if ( defined $_[0] ) {      # <-- to avoid 'Uninitialized value...' warnings
            $self->{_DSN} = $self->parse_dsn( $_[0] );
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

    # Beyond this point used to be '_init()' method. But I had to merge them together
    # since '_init()' did not serve specific purpose

    my @pms = ();
    $pms[0] = "CGI::Session::Driver::"      . $self->{_DSN}->{driver};
    $pms[1] = "CGI::Session::Serialize::"  . $self->{_DSN}->{serializer};
    $pms[2] = "CGI::Session::ID::"          . $self->{_DSN}->{id};

    for ( @pms ) {
        eval "require $_";
        if ( my $errmsg = $@ ) {
            return $self->set_error("couldn't load $_: " . $errmsg);
        }
    }

    #
    # Creating & caching driver object
    defined($self->{_OBJECTS}->{driver} = $pms[0]->new( $self->{_DRIVER_ARGS} ) )
        or return $self->set_error( "init(): couldn't create driver object: " .  $pms[0]->errstr );

    $self->{_OBJECTS}->{serializer} = $pms[1];
    $self->{_OBJECTS}->{id}         = $pms[2];

    #
    unless ( $self->{_CLAIMED_ID} ) {
        my $query = $self->query();
        eval {
            $self->{_CLAIMED_ID} = $query->cookie( $self->name ) || $query->param( $self->name );
        };
        if ( my $errmsg = $@ ) {
            return $class->set_error( "query object $query does not support cookie() and param() methods: " .  $errmsg );
        }
    }

    #
    # No session is being requested. Just return an empty session
    return $self unless $self->{_CLAIMED_ID};

    #
    # Attempting to load the session
    my $raw_data = $self->{_OBJECTS}->{driver}->retrieve( $self->{_CLAIMED_ID} );
    unless ( defined $raw_data ) {
        return $self->set_error( "load(): couldn't retrieve data: " . $self->{_OBJECTS}->{driver}->errstr );
    }
    #
    # Requested session couldn't be retrieved
    return $self unless $raw_data;

    $self->{_DATA} = $self->{_OBJECTS}->{serializer}->thaw($raw_data);
    unless ( defined $self->{_DATA} ) {
        #die $raw_data . "\n";
        return $self->set_error( "load(): couldn't thaw() data using $self->{_OBJECTS}->{serializer} :" .
                                $self->{_OBJECTS}->{serializer}->errstr );
    }
    unless (defined($self->{_DATA}) && ref ($self->{_DATA}) && (ref $self->{_DATA} eq 'HASH') &&
            defined($self->{_DATA}->{_SESSION_ID}) ) {
        return $self->set_error( "Invalid data structure returned from thaw()" );
    }

    #
    # checking if previous session ip matches current ip
    if($CGI::Session::IP_MATCH) {
      unless($self->_ip_matches) {
        $self->_set_status( STATUS_DELETED );
        $self->flush;
        return $self;
      }
    }

    #
    # checking for expiration ticker
    if ( $self->{_DATA}->{_SESSION_ETIME} ) {
        if ( ($self->{_DATA}->{_SESSION_ATIME} + $self->{_DATA}->{_SESSION_ETIME}) <= time() ) {
            $self->_set_status( STATUS_EXPIRED );   # <-- so client can detect expired sessions
            $self->_set_status( STATUS_DELETED );   # <-- session should be removed from database
            $self->flush();                         # <-- flush() will do the actual removal!
            return $self;
        }
    }

    # checking expiration tickers of individuals parameters, if any:
    my @expired_params = ();
    while (my ($param, $max_exp_interval) = each %{ $self->{_DATA}->{_SESSION_EXPIRE_LIST} } ) {
        if ( ($self->{_DATA}->{_SESSION_ATIME} + $max_exp_interval) <= time() ) {
            push @expired_params, $param;
        }
    }
    $self->clear(\@expired_params) if @expired_params;
    $self->{_DATA}->{_SESSION_ATIME} = time();      # <-- updating access time
    $self->_set_status( STATUS_MODIFIED );          # <-- access time modified above

    return $self;
}

=pod

=item id()

Returns effective ID for a session. Since effective ID and claimed ID can differ, valid session id should always
be retrieved using this method.

=item param($name)

=item param(-name=E<gt>$name)

Used in either of the above syntax returns a session parameter set to $name or undef if it doesn't exist. If it's called on a deleted method param() will issue a warning but return value is not defined.

=item param($name, $value)

=item param(-name=E<gt>$name, -value=E<gt>$value)

Used in either of the above syntax assigns a new value to $name parameter,
which can later be retrieved with previously introduced param() syntax. C<$value>
may be a scalar, arrayref or hashref.

Attempts to set parameter names that start with I<_SESSION_> will trigger
a warning and undef will be returned.

=item param_hashref()

B<Deprecated>. Use L<dataref()|/"dataref"> instead.

=item dataref()

Returns reference to session's data table:

    $params = $s->dataref();
    $sid = $params->{_SESSION_ID};
    $name= $params->{name};
    # etc...

Useful for having all session data in a hashref, but too risky to update.

=item save_param()

=item save_param($query)

=item save_param($query, \@list)

Saves query parameters to session object. In other words, it's the same as calling L<param($name, $value)|/"param"> for every single query parameter returned by C<< $query->param() >>. The first argument, if present, should be either CGI object or any object which can provide param() method. If it's undef, defaults to the return value of L<query()|/"query">, which returns C<< CGI->new >>. If second argument is present and is a reference to an array, only those query parameters found in the array will be stored in the session. undef is a valid placeholder for any argument to force default behavior.

=item load_param()

=item load_param($query)

=item load_param($query, \@list)

Loads session parameters into a query object. The first argument, if present, should be query object, or any other object which can provide param() method. If second argument is present and is a reference to an array, only parameters found in that array will be loaded to the query object.

=item clear()

=item clear('field')

=item clear(\@list)

Clears parameters from the session object.

With no parameters, all fields are cleared. If passed a single parameter or a
reference to an array, only the named parameters are cleared.

=item flush()

Synchronizes data in the buffer with its copy in disk. Normally it will be called for you just before the program terminates, or session object goes out of scope, so you should never have to flush() on your own.

=item atime()

Read-only method. Returns the last access time of the session in seconds from epoch. This time is used internally while
auto-expiring sessions and/or session parameters.

=item ctime()

Read-only method. Returns the time when the session was first created in seconds from epoch.

=item expire()

=item expire($time)

=item expire($param, $time)

Sets expiration interval relative to L<atime()|/"atime">.

If used with no arguments, returns the expiration interval if it was ever set. If no expiration was ever set, returns undef. For backwards compatibility, a method named C<etime()> does the same thing.

Second form sets an expiration time. This value is checked when previously stored session is asked to be retrieved, and if its expiration interval has passed, it will be expunged from the disk immediately. Passing 0 cancels expiration.

By using the third syntax you can set the expiration interval for a particular session parameter, say I<~logged-in>. This would cause the library call clear() on the parameter when its time is up. Passing 0 cancels expiration.

All the time values should be given in the form of seconds. Following keywords are also supported for your convenience:

    +-----------+---------------+
    |   alias   |   meaning     |
    +-----------+---------------+
    |     s     |   Second      |
    |     m     |   Minute      |
    |     h     |   Hour        |
    |     d     |   Day         |
    |     w     |   Week        |
    |     M     |   Month       |
    |     y     |   Year        |
    +-----------+---------------+

Examples:

    $session->expire("2h");                # expires in two hours
    $session->expire(0);                   # cancel expiration
    $session->expire("~logged-in", "10m"); # expires '~logged-in' parameter after 10 idle minutes

Note: all the expiration times are relative to session's last access time, not to its creation time. To expire a session immediately, call L<delete()|/"delete">. To expire a specific session parameter immediately, call L<clear([$name])|/"clear">.

=cut

*expires = \&expire;
my $prevent_warning = \&expires;
sub etime           { $_[0]->expire()  }
sub expire {
    my $self = shift;

    # no params, just return the expiration time.
    if (not @_) {
        return $self->{_DATA}->{_SESSION_ETIME};
    }
    # We have just a time
    elsif ( @_ == 1 ) {
        my $time = $_[0];
        # If 0 is passed, cancel expiration
        if ( defined $time && ($time =~ m/^\d$/) && ($time == 0) ) {
            $self->{_DATA}->{_SESSION_ETIME} = undef;
            $self->_set_status( STATUS_MODIFIED );
        }
        # set the expiration to this time
        else {
            $self->{_DATA}->{_SESSION_ETIME} = $self->_str2seconds( $time );
            $self->_set_status( STATUS_MODIFIED );
        }
    }
    # If we get this far, we expect expire($param,$time)
    # ( This would be a great use of a Perl6 multi sub! )
    else {
        my ($param, $time) = @_;
        if ( ($time =~ m/^\d$/) && ($time == 0) ) {
            delete $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{ $param };
            $self->_set_status( STATUS_MODIFIED );
        } else {
            $self->{_DATA}->{_SESSION_EXPIRE_LIST}->{ $param } = $self->_str2seconds( $time );
            $self->_set_status( STATUS_MODIFIED );
        }
    }
    return 1;
}

# =head2 _str2seconds()
#
# my $secs = $self->_str2seconds('1d')
#
# Takes a CGI.pm-style time representation and returns an equivalent number
# of seconds.
#
# See the docs of expire() for more detail.
#
# =cut

sub _str2seconds {
    my $self = shift;
    my ($str) = @_;

    return unless defined $str;
    return $str if $str =~ m/^[-+]?\d+$/;

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
        die "_str2seconds(): couldn't parse '$str' into \$koef and \$d parts. Possible invalid syntax";
    }
    return $koef * $_map{ $d };
}


=pod

=item is_new()

Returns true only for a brand new session.

=item is_expired()

Tests whether session initialized using L<load()|/"load"> is to be expired. This method works only on sessions initialized with load():

    $s = CGI::Session->load() or die CGI::Session->errstr;
    if ( $s->is_expired ) {
        die "Your session expired. Please refresh";
    }
    if ( $s->is_empty ) {
        $s = $s->new() or die $s->errstr;
    }


=item is_empty()

Returns true for sessions that are empty. It's preferred way of testing whether requested session was loaded successfully or not:

    $s = CGI::Session->load($sid);
    if ( $s->is_empty ) {
        $s = $s->new();
    }

Actually, the above code is nothing but waste. The same effect could've been achieved by saying:

    $s = CGI::Session->new( $sid );

L<is_empty()|/"is_empty"> is useful only if you wanted to catch requests for expired sessions, and create new session afterwards. See L<is_expired()|/"is_expired"> for an example.

=item delete()

Deletes a session from the data store and empties session data from memory, completely, so subsequent read/write requests on the same object will fail. Technically speaking, it will only set object's status to I<STATUS_DELETED> and will trigger L<flush()|/"flush">, and flush() will do the actual removal.

=item find( \&code )

=item find( $dsn, \&code )

=item find( $dsn, \&code, \%dsn_args )

Experimental feature. Executes \&code for every session object stored in disk, passing initialized CGI::Session object as the first argument of \&code. Useful for housekeeping purposes, such as for removing expired sessions. Following line, for instance, will remove sessions already expired, but are still in disk:

    CGI::Session->find( sub {} );

Notice, above \&code didn't have to do anything, because load(), which is called to initialize sessions inside find(), will automatically remove expired sessions. Following example will remove all the objects that are 10+ days old:

    CGI::Session->find( \&purge );
    sub purge {
        my ($session) = @_;
        next if $session->empty;    # <-- already expired?!
        if ( ($session->ctime + 3600*240) <= time() ) {
            $session->delete() or warn "couldn't remove " . $session->id . ": " . $session->errstr;
        }
    }

B<Note:> find() is meant to be convenient, not necessarily efficient. It's best suited in cron scripts.

=back

=head1 MISCELLANEOUS METHODS

=over 4

=item remote_addr()

Returns the remote address of the user who created the session for the first time. Returns undef if variable REMOTE_ADDR wasn't present in the environment when the session was created.

=cut

sub remote_addr {   return $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR}   }

=pod

=item errstr()

Class method. Returns last error message from the library.

=item dump()

Returns a dump of the session object. Useful for debugging purposes only.

=item header()

Replacement for L<CGI.pm|CGI>'s header() method. Without this method, you usually need to create a CGI::Cookie object and send it as part of the HTTP header:

    $cookie = CGI::Cookie->new(-name=>$session->name, -value=>$session->id);
    print $cgi->header(-cookie=>$cookie);

You can minimize the above into:

    print $session->header();

It will retrieve the name of the session cookie from $CGI::Session::NAME variable, which can also be accessed via CGI::Session->name() method. If you want to use a different name for your session cookie, do something like following before creating session object:

    CGI::Session->name("MY_SID");
    $session = new CGI::Session(undef, $cgi, \%attrs);

Now, $session->header() uses "MY_SID" as a name for the session cookie.

=item query()

Returns query object associated with current session object. Default query object class is L<CGI.pm|CGI>.

=back

=head2 DEPRECATED METHODS

These methods exist solely for for compatibility with CGI::Session 3.x.

=over 4

=item close()

Closes the session. Using flush() is recommended instead, since that's exactly what a call
to close() does now.

=back 

=head1 DISTRIBUTION

CGI::Session consists of several components such as L<drivers|"DRIVERS">, L<serializers|"SERIALIZERS"> and L<id generators|"ID GENERATORS">. This section lists what is available.

=head2 DRIVERS

Following drivers are included in the standard distribution:

=over 4

=item *

L<file|CGI::Session::Driver::file> - default driver for storing session data in plain files. Full name: B<CGI::Session::Driver::file>

=item *

L<db_file|CGI::Session::Driver::db_file> - for storing session data in BerkelyDB. Requires: L<DB_File>.
Full name: B<CGI::Session::Driver::db_file>

=item *

L<mysql|CGI::Session::Driver::mysql> - for storing session data in MySQL tables. Requires L<DBI|DBI> and L<DBD::mysql|DBD::mysql>.
Full name: B<CGI::Session::Driver::mysql>

=item *

L<sqlite|CGI::Session::Driver::sqlite> - for storing session data in SQLite. Requires L<DBI|DBI> and L<DBD::SQLite|DBD::SQLite>.
Full name: B<CGI::Session::Driver::sqlite>

=back

=head2 SERIALIZERS

=over 4

=item *

L<default|CGI::Session::Serialize::default> - default data serializer. Uses standard L<Data::Dumper|Data::Dumper>.
Full name: B<CGI::Session::Serialize::default>.

=item *

L<storable|CGI::Session::Serialize::storable> - serializes data using L<Storable>. Requires L<Storable>.
Full name: B<CGI::Session::Serialize::storable>.

=item *

L<freezethaw|CGI::Session::Serialize::freezethaw> - serializes data using L<FreezeThaw>. Requires L<FreezeThaw>.
Full name: B<CGI::Session::Serialize::freezethaw>

=back

=head2 ID GENERATORS

Following ID generators are available:

=over 4

=item *

L<md5|CGI::Session::ID::md5> - generates 32 character long hexadecimal string. Requires L<Digest::MD5|Digest::MD5>.
Full name: B<CGI::Session::ID::md5>.

=item *

L<incr|CGI::Session::ID::incr> - generates incremental session ids.

=item *

L<static|CGI::Session::ID::static> - generates static session ids. B<CGI::Session::ID::static>

=back


=head1 CREDITS

CGI::Session evolved to what it is today with the help of following developers. The list doesn't follow any strict order, but somewhat chronological. Specifics can be found in F<Changes> file

=over 4

=item Andy Lester E<lt>alester@flr.follett.comE<gt>

=item Brian King E<lt>mrbbking@mac.comE<gt>

=item Olivier Dragon E<lt>dragon@shadnet.shad.caE<gt>

=item Adam Jacob E<lt>adam@sysadminsith.orgE<gt>

=item Igor Plisco E<lt>igor@plisco.ruE<gt>

=item Mark Stosberg E<lt>markstos@cpan.orgE<gt>

=item Matt LeBlanc

=item Shawn Sorichetti

=back

=head1 COPYRIGHT

Copyright (C) 2001-2005 Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt>. All rights reserved.
This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=head1 PUBLIC CODE REPOSITORY

You can see what the developers have been up to since the last release by
checking out the code repository. You can browse the Subversion repository from here:

 http://svn.cromedome.net/

Or check it directly with C<svn> from here:

 svn://svn.cromedome.net/CGI-Session

=head1 SUPPORT

If you need help using CGI::Session consider the mailing list. You can ask the list by sending your questions to
cgi-session-user@lists.sourceforge.net .

You can subscribe to the mailing list at https://lists.sourceforge.net/lists/listinfo/cgi-session-user .

=head1 AUTHOR

Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt>, http://author.handalak.com/

Mark Stosberg became a co-maintainer during the development of 4.0. C<markstos@cpan.org>.

=head1 SEE ALSO

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut

1;

