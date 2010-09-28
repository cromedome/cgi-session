package CGI::Session;

use strict;
use Carp;
use CGI::Session::ErrorHandler;

@CGI::Session::ISA      = qw( CGI::Session::ErrorHandler );
$CGI::Session::VERSION  = '4.45';
$CGI::Session::NAME     = 'CGISESSID';
$CGI::Session::IP_MATCH = 0;

sub STATUS_UNSET    () { 1 << 0 } # denotes session that's not yet initialized
sub STATUS_NEW      () { 1 << 1 } # denotes session that's just created
sub STATUS_MODIFIED () { 1 << 2 } # denotes session that needs synchronization
sub STATUS_DELETED  () { 1 << 3 } # denotes session that needs deletion
sub STATUS_EXPIRED  () { 1 << 4 } # denotes session that was expired.
sub STATUS_IGNORE   () { 1 << 5 } # denotes session that is ignored by find() and, hence, flush().

sub import {
    my ($class, @args) = @_;

    return unless @args;

  ARG:
    foreach my $arg (@args) {
        if ($arg eq '-ip_match') {
            $CGI::Session::IP_MATCH = 1;
            last ARG;
        }
    }
}

sub new {
    my ($class, @args) = @_;

    my $self;
    if (ref $class) {
        #
        # Called as an object method as in $session->new()...
        #
        $self  = bless { %$class }, ref( $class );
        $class = ref $class;
        $self->_reset_status();
        #
        # Object may still have public data associated with it, but we
        # don't care about that, since we want to leave that to the
        # client's disposal. However, if new() was requested on an
        # expired session, we already know that '_DATA' table is
        # empty, since it was the job of flush() to empty '_DATA'
        # after deleting. How do we know flush() was already called on
        # an expired session? Because load() - constructor always
        # calls flush() on all to-be expired sessions
        #
    }
    else {
        #
        # Called as a class method as in CGI::Session->new()
        #

        # Start fresh with error reporting. Errors in past objects shouldn't affect this one.
        $class->set_error('');

        $self = $class->load( @args );
        if (not defined $self) {
            return $class->set_error( "new(): failed: " . $class->errstr );
        }
    }

    my $dataref = $self->{_DATA};
    unless ($dataref->{_SESSION_ID}) {
        #
        # Absence of '_SESSION_ID' can only signal:
        # * Expired session: Because load() - constructor is required to
        #                    empty contents of _DATA - table
        # * Unavailable session: Such sessions are the ones that don't
        #                    exist on datastore, but are requested by client
        # * New session: When no specific session is requested to be loaded
        #
        my $id = $self->_id_generator()->generate_id(
                                                     $self->{_DRIVER_ARGS},
                                                     $self->{_CLAIMED_ID}
                                                     );
        unless (defined $id) {
            return $self->set_error( "Couldn't generate new SESSION-ID" );
        }
        $dataref->{_SESSION_ID} = $id;
        $dataref->{_SESSION_CTIME} = $dataref->{_SESSION_ATIME} = time();
        $dataref->{_SESSION_REMOTE_ADDR} = $ENV{REMOTE_ADDR} || "";
        $self->_set_status( STATUS_NEW );
    }
    return $self;

} # End of new.

sub DESTROY {
    $_[0]->flush();
}

sub close              {   $_[0]->flush()      }

*param_hashref      = \&dataref;
my $avoid_single_use_warning = *param_hashref;
sub dataref            { $_[0]->{_DATA}        }

sub is_empty           { !defined($_[0]->id)   }

sub is_expired         { $_[0]->_test_status( STATUS_EXPIRED ) }

sub is_new             { $_[0]->_test_status( STATUS_NEW ) }

sub id                 { return defined($_[0]->dataref) ? $_[0]->dataref->{_SESSION_ID}    : undef }

# Last Access Time
sub atime              { return defined($_[0]->dataref) ? $_[0]->dataref->{_SESSION_ATIME} : undef }

# Creation Time
sub ctime              { return defined($_[0]->dataref) ? $_[0]->dataref->{_SESSION_CTIME} : undef }

sub _driver {
    my $self = shift;
    defined($self->{_OBJECTS}->{driver}) and return $self->{_OBJECTS}->{driver};
    my $pm = "CGI::Session::Driver::" . $self->{_DSN}->{driver};
    defined($self->{_OBJECTS}->{driver} = $pm->new( $self->{_DRIVER_ARGS} ))
        or die $pm->errstr();
    return $self->{_OBJECTS}->{driver};
}

sub _serializer     {
    my $self = shift;
    defined($self->{_OBJECTS}->{serializer}) and return $self->{_OBJECTS}->{serializer};
    return $self->{_OBJECTS}->{serializer} = "CGI::Session::Serialize::" . $self->{_DSN}->{serializer};
}


sub _id_generator   {
    my $self = shift;
    defined($self->{_OBJECTS}->{id}) and return $self->{_OBJECTS}->{id};
    return $self->{_OBJECTS}->{id} = "CGI::Session::ID::" . $self->{_DSN}->{id};
}

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

    eval "require $self->{_QUERY_CLASS}";

    if ($@) {
        croak "Error. Unable to 'require' $self->{_QUERY_CLASS}: $@";
    }

    return $self->{_QUERY} = $self->{_QUERY_CLASS}->new();
}

sub name {
    my($self, $name) = @_;

    if (ref $self) {
        if ($name) {
            $self->{_NAME} = $name;
        }
        return $self->{_NAME} || $CGI::Session::NAME;
    }

    $CGI::Session::NAME = $name if ($name);

    return $CGI::Session::NAME;
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
    $self->{_STATUS} |= $_[0];
}


sub _unset_status {
    my $self = shift;
    croak "_unset_status(): usage error" unless @_;
    $self->{_STATUS} &= ~$_[0];
}


sub _reset_status {
    $_[0]->{_STATUS} = STATUS_UNSET;
}

sub _test_status {
    return $_[0]->{_STATUS} & $_[1];
}

sub _report_status {
    my(@status) = 'Status:';
    if (! defined $_[0]->{_STATUS}) {
        push @status, 'Not defined';
    } else {
        my(%status) =
            (
                UNSET    => STATUS_UNSET,
                NEW      => STATUS_NEW,
                MODIFIED => STATUS_MODIFIED,
                DELETED  => STATUS_DELETED,
                EXPIRED  => STATUS_EXPIRED,
                IGNORE   => STATUS_IGNORE,
            );
        for (keys %status) {
            if ($_[0]->_test_status($status{$_}) ) {
                push @status, $_;
            }
        }
    }

    return join(' ', @status);
}

sub flush {
    my $self = shift;

    # Would it be better to die or err if something very basic is wrong here?
    # I'm trying to address the DESTROY related warning
    # from: http://rt.cpan.org/Ticket/Display.html?id=17541
    # return unless defined $self;

    return unless $self->id;            # <-- empty session

    # neither new, nor deleted nor modified
    # Warning: $self->_test_status(STATUS_UNSET | STATUS_IGNORE) does not work on the next line.
    return if !defined($self->{_STATUS}) or $self->{_STATUS} == STATUS_UNSET or $self->_test_status(STATUS_IGNORE);

    if ( $self->_test_status(STATUS_NEW) && $self->_test_status(STATUS_DELETED) ) {
        $self->{_DATA} = {};
        return $self->_unset_status(STATUS_NEW | STATUS_DELETED);
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

    if ( $self->_test_status(STATUS_NEW | STATUS_MODIFIED) ) {
        my $datastr = $serializer->freeze( $self->dataref );
        unless ( defined $datastr ) {
            return $self->set_error( "flush(): couldn't freeze data: " . $serializer->errstr );
        }
        my $etime = undef;
        $etime = time + $self->{_DATA}->{_SESSION_ETIME} if ($self->{_DATA}->{_SESSION_ETIME});
        defined( $driver->store($self->id, $datastr, $etime) ) or
            return $self->set_error( "flush(): couldn't store datastr: " . $driver->errstr);
        $self->_unset_status(STATUS_NEW | STATUS_MODIFIED);
    }
    return 1;

} # End of flush.

sub trace {}
sub tracemsg {}

sub param {
    my ($self, @args) = @_;

    if ($self->_test_status( STATUS_DELETED )) {
        carp "param(): attempt to read/write deleted session";
    }

    # USAGE: $s->param();
    # DESC:  Returns all the /public/ parameters
    if (@args == 0) {
        return grep { !/^_SESSION_/ } keys %{ $self->{_DATA} };
    }
    # USAGE: $s->param( $p );
    # DESC: returns a specific session parameter
    elsif (@args == 1) {
        return $self->{_DATA}->{ $args[0] }
    }


    # USAGE: $s->param( -name => $n, -value => $v );
    # DESC:  Updates session data using CGI.pm's 'named param' syntax.
    #        Only public records can be set!
    my %args = @args;
    my ($name, $value) = @args{ qw(-name -value) };
    if (defined $name && defined $value) {
        if ($name =~ m/^_SESSION_/) {

            carp "param(): attempt to write to private parameter";
            return undef;
        }
        $self->_set_value($name, $value);
        return $value;
    }

    # USAGE: $s->param(-name=>$n);
    # DESC:  access to session data (public & private) using CGI.pm's 'named parameter' syntax.
    return $self->{_DATA}->{ $args{'-name'} } if defined $args{'-name'};

    # USAGE: $s->param($name, $value);
    # USAGE: $s->param($name1 => $value1, $name2 => $value2 [,...]);
    # DESC:  updates one or more **public** records using simple syntax
    if ((@args % 2) == 0) {
        my $modified_cnt = 0;
    ARG_PAIR:
        while (my ($name, $value) = each %args) {
            if ( $name =~ m/^_SESSION_/) {
                carp "param(): attempt to write to private parameter";
                next ARG_PAIR;
            }
            $self->_set_value($name, $value);
            ++$modified_cnt;
        }
        return $modified_cnt;
    }

    # If we reached this far none of the expected syntax were
    # detected. Syntax error
    croak "param(): usage error. Invalid syntax";

} # End of param.


# =head2 _set_value($name, $new_value)
#
# This method takes the name of any field within the object's data structure,
# and a value to be stored there, but only updates the data structure if the current
# value differs from the new value. Hence:
#
#     $session->_set_value(some_key => $some_value)
#
# means $self->{_DATA}->{'some_key'} I<may> be updated.
#
# If the update takes place, this method sets the modified flag on the session.
#
# Note: All objects loaded via a call to load() - either from within the object or by the user -
# have their access time set, and hence have their modified flag set. This in turn means all such
# object are written to disk by flush(). This behaviour has not changed.
#
# Return value: 0 if the object was not modified, and 1 if it was.
#
# This method is private because users should not base any code on knowing the internal
# structure of session objects.

sub _set_value {
    my($self, $key, $new_value) = @_;
    my($old_value) = $self->{_DATA}->{$key};
    my($modified)  = 0;

    if (defined $old_value) {
        if (defined $new_value) {
            if ($old_value eq $new_value) {
                # Both values defined, and equal to each other. Do nothing.
            }
            else {   # Both values defined, and different from each other.
                $self->{_DATA}->{ $key } = $new_value;
                $self->_set_status(STATUS_MODIFIED);
                $modified = 1;
            }
        }
        else {   # Old value defined. New value not defined.
            $self->{_DATA}->{ $key } = $new_value;
            $self->_set_status(STATUS_MODIFIED);
            $modified = 1;
        }
    }
    elsif (defined $new_value) {   # Old value not defined. New value defined.
        $self->{_DATA}->{ $key } = $new_value;
        $self->_set_status(STATUS_MODIFIED);
        $modified = 1;
    }
    # else: Neither old nor new value defined. Do nothing.

    return $modified;
}

sub delete {    $_[0]->_set_status( STATUS_DELETED )    }


*header = \&http_header;
my $avoid_single_use_warning_again = *header;
sub http_header {
    my $self = shift;
    if ($self->query->can('cookie') ) {
        return $self->query->header(-cookie=>$self->cookie, -type=>'text/html', @_);
    }
    else {
        return $self->query->header(-type=>'text/html', @_);
    }
}

sub cookie {
    my $self = shift;

    my $query = $self->query();
    my $cookie= undef;

    if ( $self->is_expired ) {
        $cookie = $query->cookie( -name=>$self->name, -value=>$self->id, -expires=> '-1d', @_ );
    }
    elsif ( my $t = $self->expire ) {
        $cookie = $query->cookie( -name=>$self->name, -value=>$self->id, -expires=> '+' . $t . 's', @_ );
    }
    else {
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

    for ( grep { ! /^_SESSION_/ } @$params ) {
        $self->_set_value($_, undef);
    }
}


sub find {
    my $class       = shift;
    my ($dsn, $coderef, $dsn_args);

    # find( \%code )
    if ( @_ == 1 ) {
        $coderef = $_[0];
    }
    # find( $dsn, \&code, \%dsn_args )
    else {
        ($dsn, $coderef, $dsn_args) = @_;
    }

    unless ( $coderef && ref($coderef) && (ref $coderef eq 'CODE') ) {
        croak "find(): usage error.";
    }

    my $driver;
    if ( $dsn ) {
        my $hashref = $class->parse_dsn( $dsn );
        $driver     = $hashref->{driver};
    }
    $driver ||= "file";
    my $pm = "CGI::Session::Driver::" . ($driver =~ /(.*)/)[0];
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
        my $session = $class->load( $dsn, $sid, $dsn_args, {find_is_caller => 1, update_atime => 0} );
        unless ( $session ) {
            return $class->set_error( "find(): couldn't load session '$sid'. " . $class->errstr );
        }
        if ( $session->_test_status(STATUS_IGNORE) ) {
          # Ignore. IP_MATCH set and IPs do not match.
          # Ensure we don't accidently think the session has been modified.
            $session->_reset_status(STATUS_IGNORE);
        }
        else {
            $coderef->( $session );
        }
    };

    defined($driver_obj->traverse( $driver_coderef ))
        or return $class->set_error( "find(): traverse seems to have failed. " . $driver_obj->errstr );
    return 1;

} # End of find.

=pod

=head1 NAME

CGI::Session - persistent session data in CGI applications

=head1 SYNOPSIS

    # Object initialization:
    use CGI::Session;
    $session = CGI::Session->new();

    $CGISESSID = $session->id();

    # Send proper HTTP header with cookies:
    print $session->header();

    # Storing data in the session:
    $session->param('f_name', 'Sherzod');
    # or
    $session->param(-name=>'l_name', -value=>'Ruzmetov');

    # Flush the data from memory to the storage driver at least before your
    # program finishes since auto-flushing can be client code errors
    # such as circular references or attempted use of out-of-scope
    # database handles.
    $session->flush();

    # Retrieving data:
    my $f_name = $session->param('f_name');
    # or
    my $l_name = $session->param(-name=>'l_name');

    # Clearing a certain session parameter:
    $session->clear(["l_name", "f_name"]);

    # Expire '_is_logged_in' flag after 10 idle minutes:
    $session->expire('is_logged_in', '+10m')

    # Expire the session itself after 1 idle hour:
    $session->expire('+1h');

    # Delete the session for good:
    $session->delete();
    $session->flush(); # Recommended practice says use flush() after delete().

=head1 DESCRIPTION

CGI::Session provides an easy, reliable and modular session management system across HTTP requests.

=head1 METHODS

Following is the overview of all the available methods accessible via CGI::Session object.

=head2 new()

=head2 new( $sid )

=head2 new( $query )

=head2 new( $dsn, $query||$sid )

=head2 new( $dsn, $query||$sid, \%dsn_args )

=head2 new( $dsn, $query||$sid, \%dsn_args, \%session_params )

Constructor. Returns new session object, or undef on failure.

Error message is accessible through L<errstr()|/"errstr()">.

If called on an already initialized session, will re-initialize the session based on already configured object. This is only useful after a call to L<load()|/"load()">.

C<new()>, like C<load()>, can accept up to four arguments:

=over 4

=item $dsn

Data Source Name - a string. See samples below.

Default: I<driver:file;serializer:default;id:md5>.

=item $query || $sid

Query object, or a string representing the session id.

Default: C<< CGI->new() >>.

This default can be overridden. See {query_class => 'Some::Class'} under \%session_params.

=item \%dsn_args

A hashref of arguments used by the $dsn parser.

Whether or not it's optional depends on the $dsn parser.

See the docs for the subclasses - e.g. C<CGI::Session::Driver::postgresql> - for details.

If undef is supplied for \%dsn_args, it is converted into the default.

Default: {}.

=item \%session_params

A optional hashref of arguments used by the session object.

Note: if you don't wish to supply anything for \%dsn_args, just use {}, so that \%session_params
will not be assumed to be \%dsn_args.

Keys in \%session_params:

=over 4

=item name

The value defines the name of the query parameter or cookie name to be used.

It defaults to I<$CGI::Session::NAME>, which defaults to I<CGISESSID>.

The current value of the query parameter or cookie name can be set and queried with the L<name()|/"name($new_name)"> method.

You are strongly discouraged from using the global variable I<$CGI::Session::NAME>, since it is
deprecated (as are all global variables) and will be removed in a future version of this module.

=item query_class

The value specifies the class of the query object, when the second parameter to L<new()|/"new()">
or L<load()|/"load()"> is not an object.

In such a case, C<CGI::Session> I<requires> an object of some class to create a query object.

So, if you wish to use a substitute to C<CGI>, use something like {query_class => 'CGI::Simple'}.

The default is {query_class => 'CGI'}.

=item update_atime

The value (0 or 1) determines whether or not C<load()> updates the atime of the session upon
loading it. Updating atime means L<flush()|/"flush()"> will write the session to storage even
if none of the session's parameters are changed by the user.

{update_atime => 0} stops the atime being updated by C<load()>.

{update_atime => 1) causes C<load()> to update atime, and hence forces the session to be flushed.

The default is {update_atime => 1}, since C<load()> always did that in the past.

=back

If undef is supplied for \%session_params, it is converted into the default.

Default: {query_class => 'CGI', update_atime => 1}.

=back

If called with a single argument, it will be treated either as C<$query> object, or C<$sid>, depending on its type.

If the argument is a string , C<new()> will treat it as session id and will attempt to retrieve the session from data store. If it fails, will create a new session id, which will be accessible through L<id()|/"id()"> method.

If the argument is an object, C<cookie()> and C<param()> methods will be called on that object to recover a potential C<$sid> and retrieve it from data store.

If that fails, C<new()> will create a new session id, which will be accessible through L<id()|/"id()"> method.

If called with two arguments, the first will be treated as $dsn, and the second will be treated as $query or $sid or undef, depending on its type.

Some examples of this syntax are:

    $s = CGI::Session->new("driver:mysql", undef, {}, {name => 'sid'});
    $s = CGI::Session->new("driver:sqlite", $sid);
    $s = CGI::Session->new("driver:db_file", $query);
    $s = CGI::Session->new("serializer:storable;id:incr", $sid);
    # etc...

Briefly, C<new()> will return an initialized session object with a valid id, whereas C<load()> may return
an empty session object with an undefined id.

Tests are provided (t/new_with_undef.t and t/load_with_undef.t) to clarify the result of calling C<new()> and C<load()>
with undef, or with an initialized CGI-like object with an undefined or fake CGISESSID.

You are strongly advised to run the old-fashioned 'make test TEST_FILES=t/new_with_undef.t TEST_VERBOSE=1'
or the new-fangled 'prove -v t/new_with_undef.t', for both new*.t and load*.t, and examine the output.

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

    $s = CGI::Session->new("driver:DB_File;serializer:FreezeThaw", undef);

If called with three arguments, first two will be treated as in the previous example, and third argument will be C<\%dsn_args>, which will be passed to C<$dsn> components (namely, driver, serializer and id generators) for initialization purposes. Since all the $dsn components must initialize to some default value, this third argument should not be required for most drivers to operate properly.

If called with four arguments, the first three match previous examples. The fourth argument must be a hash reference with parameters to be used by the CGI::Session object. (see \%session_params above )

undef is acceptable as a valid placeholder to any of the above arguments, which will force default behavior.

=head2 load()

=head2 load( $query||$sid )

=head2 load( $dsn, $query||$sid )

=head2 load( $dsn, $query, \%dsn_args )

=head2 load( $dsn, $query, \%dsn_args, \%session_params )

Accepts the same arguments as L<new()|/"new()">, and also returns a new session object, or
undef on failure.  The difference is, L<new()|/"new()"> can create a new session if
it detects expired and non-existing sessions, but C<load()> does not.

C<load()> is useful to detect expired or non-existing sessions without forcing the library to create new sessions. So now you can do something like this:

    $cgi = CGI->new;
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

Notice: All I<expired> sessions are empty, but not all I<empty> sessions are expired!

The 4th parameter to load() must be a hashref (or undef).

Brief summary: C<new()> will return an initialized session object with a valid id, whereas C<load()> may return
an empty session object with an undefined id.

=cut

# pass a true value as the fourth parameter if you want to skip the changing of
# access time This isn't documented more formally, because it only called by
# find().

# find_is_caller is a session option that is only used internally, so is not documented publically.
# L<find()|/"find()"> sets the find_is_caller key in this hashref, so C<load()> knows not to
# delete sessions whose IP addresses don't match, when called by L<find()|/"find()">.
# This only matters when $CGI::Session::IP_MATCH is set to 1, which can be achieved by
# either setting the global variable directly, or loading the module with:
#
#     use CGI::session qw/ip_match/;
#
# The purpose is so that when $CGI::Session::IP_MATCH is reset (the default), sessions are loaded as normal.
# But, when $CGI::Session::IP_MATCH is set to 1, there are 3 situations:
#
# * The IP of the client and the session match -> Load the session
# * The IPs don't match, and C<find> is the caller. -> don't load the session
# * The IPs don't match, and C<find> is not the caller -> delete the session.

sub load {
    my $class = shift;
    return $class->set_error( "called as instance method")    if ref $class;
    return $class->set_error( "Too many arguments provided to load()")  if @_ > 5;

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
        _CLAIMED_ID   => undef,       # id **claimed** by client
        _DRIVER_ARGS  => {},          # arguments to be passed to driver
        _DSN          => {},          # parsed DSN params
        _NAME         => $CGI::SESSION::NAME, # Default query parameter or cookie name.
        _OBJECTS      => {},          # keeps necessary objects
        _QUERY        => undef,       # query object
        _QUERY_CLASS  => 'CGI',       # The class of the query object.
        _STATUS       => STATUS_UNSET,# status of the session object
        _UPDATE_ATIME => 1,           # Set to 1 to update atime upon loading, hence causing flushing.
    }, $class;

    my ($dsn, $query_or_sid, $dsn_args);
    my $params = {};
    # load($query||$sid)
    if ( @_ == 1 ) {
        $self->_set_query_or_sid($_[0]);
    }
    # Two or more args passed:
    # load($dsn, $query||$sid)
    elsif ( @_ > 1 ) {
        ($dsn, $query_or_sid, $dsn_args, $params) = @_;

        # This is part of the patches for RT#33437 and RT#47795.
        if (! defined $dsn_args) {
            $dsn_args = {}
        }
        elsif ( ! (ref $dsn_args && (ref $dsn_args eq 'HASH') ) ) {
            return $class->set_error( "3rd parameter to load() must be hashref (or undef)");
        }

        if (! defined $params) {
            $params = {find_is_caller => 0, query_class => 'CGI', update_atime => 1};
        }
        elsif ( ! (ref $params && (ref $params eq 'HASH') ) ) {
            return $class->set_error( "4th parameter to load() must be hashref (or undef)");
        }

        if ($params->{'name'}) {
            $self->{_NAME} = $params->{'name'};
        }

        # Must use defined here because the value can be 0.

        if ($params->{'query_class'}) {
            $self->{_QUERY_CLASS} = $params->{'query_class'};
        }

        # Must use defined here because the value can be 0.

        if (defined $params->{'update_atime'}) {
            $self->{_UPDATE_ATIME} = $params->{'update_atime'};
        }

        if ( defined $dsn ) {      # <-- to avoid 'Uninitialized value...' warnings
            $self->{_DSN} = $self->parse_dsn($dsn);
        }
        $self->_set_query_or_sid($query_or_sid);

        # load($dsn, $query, \%dsn_args);

        $self->{_DRIVER_ARGS} = $dsn_args if defined $dsn_args;
    }

    $self->_load_pluggables();

    # Did load_pluggable fail? If so, return undef, just like $class->set_error() would
    return undef if $class->errstr;

    if (not defined $self->{_CLAIMED_ID}) {
        my $query = $self->query();
        eval {
            $self->{_CLAIMED_ID} = $query->can('cookie') ? ($query->cookie( $self->name ) || $query->param( $self->name ) ) : $query->param( $self->name );
        };
        if ( my $errmsg = $@ ) {
            return $class->set_error( "query object $query does not support cookie() or param() methods: " .  $errmsg );
        }
    }

    # No session is being requested. Just return an empty session
    return $self unless $self->{_CLAIMED_ID};

    # Attempting to load the session
    my $driver = $self->_driver();
    my $raw_data = $driver->retrieve( $self->{_CLAIMED_ID} );
    unless ( defined $raw_data ) {
        return $self->set_error( "load(): couldn't retrieve data: " . $driver->errstr );
    }

    # Requested session couldn't be retrieved
    return $self unless $raw_data;

    my $serializer = $self->_serializer();
    $self->{_DATA} = $serializer->thaw($raw_data);
    unless ( defined $self->{_DATA} ) {
        #die $raw_data . "\n";
        return $self->set_error( "load(): couldn't thaw() data using $serializer:" .
                                $serializer->errstr );
    }
    unless (defined($self->{_DATA}) && ref ($self->{_DATA}) && (ref $self->{_DATA} eq 'HASH') &&
            defined($self->{_DATA}->{_SESSION_ID}) ) {
        return $self->set_error( "Invalid data structure returned from thaw()" );
    }

    # checking if previous session ip matches current ip
    if($CGI::Session::IP_MATCH) {
      if ($self->_ip_matches) {
        # Fall thru.
      }
      elsif ($params->{find_is_caller}) {
        # Ignore. Caller (find) must check if to be ignored.
          $self->_set_status( STATUS_IGNORE );
          return $self;
      }
      else {
        # IP does not match. Caller is not find. Delete.
        $self->_set_status( STATUS_DELETED );
        $self->flush;
        return $self;
      }
    }

    # checking for expiration ticker
    if ( $self->{_DATA}->{_SESSION_ETIME} ) {
        if ( ($self->{_DATA}->{_SESSION_ATIME} + $self->{_DATA}->{_SESSION_ETIME}) <= time() ) {
            $self->_set_status( STATUS_EXPIRED |    # <-- so client can detect expired sessions
                                STATUS_DELETED );   # <-- session should be removed from database
            $self->flush();                         # <-- flush() will do the actual removal!
            return $self;
        }
    }

    # checking expiration tickers of individuals parameters, if any:
    my @expired_params = ();
    if ($self->{_DATA}->{_SESSION_EXPIRE_LIST}) {
        while (my ($param, $max_exp_interval) = each %{ $self->{_DATA}->{_SESSION_EXPIRE_LIST} } ) {
            if ( ($self->{_DATA}->{_SESSION_ATIME} + $max_exp_interval) <= time() ) {
                push @expired_params, $param;
            }
        }
    }
    $self->clear(\@expired_params) if @expired_params;

    if ( $self->{_UPDATE_ATIME} ) {
        $self->_set_value('_SESSION_ATIME', time);
    }

    return $self;

} # End of load.


# set the input as a query object or session ID, depending on what it looks like.
sub _set_query_or_sid {
    my $self = shift;
    my $query_or_sid = shift;
    if ( ref $query_or_sid){ $self->{_QUERY}       = $query_or_sid  }
    else                   { $self->{_CLAIMED_ID}  = $query_or_sid  }
}


sub _load_pluggables {
    my ($self) = @_;

    my %DEFAULT_FOR = (
                       driver     => "file",
                       serializer => "default",
                       id         => "md5",
                       );
    my %SUBDIR_FOR  = (
                       driver     => "Driver",
                       serializer => "Serialize",
                       id         => "ID",
                       );
    my $dsn = $self->{_DSN};
    foreach my $plug qw(driver serializer id) {
        my $mod_name = $dsn->{ $plug };
        if (not defined $mod_name) {
            $mod_name = $DEFAULT_FOR{ $plug };
        }
        if ($mod_name =~ /^(\w+)$/) {

            # Looks good.  Put it into the dsn hash
            $dsn->{ $plug } = $mod_name = $1;

            # Put together the actual module name to load
            my $prefix = join '::', (__PACKAGE__, $SUBDIR_FOR{ $plug }, q{});
            $mod_name = $prefix . $mod_name;

            ## See if we can load load it
            eval "require $mod_name";
            if ($@) {
                my $msg = $@;
                return $self->set_error("couldn't load $mod_name: " . $msg);
            }
        }
        else {
            # do something here about bad name for a pluggable
        }
    }
    return;
}

=pod

=head2 id()

Returns effective ID for a session. Since effective ID and claimed ID can differ, valid session id should always
be retrieved using this method.

=head2 param($name)

=head2 param(-name=E<gt>$name)

Used in either of the above syntax returns a session parameter set to $name or undef if it doesn't exist. If it's called on a deleted method param() will issue a warning but return value is not defined.

=head2 param($name, $value)

=head2 param(-name=E<gt>$name, -value=E<gt>$value)

Used in either of the above syntax assigns a new value to $name parameter,
which can later be retrieved with previously introduced param() syntax. C<$value>
may be a scalar, arrayref or hashref.

Attempts to set parameter names that start with I<_SESSION_> will trigger
a warning and undef will be returned.

=head2 param_hashref()

B<Deprecated>. Use L<dataref()|/"dataref()"> instead.

=head2 dataref()

Returns reference to session's data table:

    $params = $s->dataref();
    $sid = $params->{_SESSION_ID};
    $name= $params->{name};
    # etc...

Useful for having all session data in a hashref, but too risky to update.

=head2 save_param()

=head2 save_param($query)

=head2 save_param($query, \@list)

Saves query parameters to session object.
In other words, it's the same as calling L<param($name, $value)|/"param"> for every single query parameter returned by C<< $query->param() >>.
The first argument, if present, should be a CGI-like object (which can provide a param() method).
If it's undef, defaults to the return value of L<query()|/"query()">, which returns C<< CGI->new >> by default, but this can be overridden.
If second argument is present and is a reference to an array, only those query parameters found in the array will be stored in the session.
undef is a valid placeholder for any argument to force default behavior.

=head2 load_param()

=head2 load_param($query)

=head2 load_param($query, \@list)

Loads session parameters into a query object. The first argument, if present, should be query object, or any other object which can provide param() method. If second argument is present and is a reference to an array, only parameters found in that array will be loaded to the query object.

=head2 clear()

=head2 clear('field')

=head2 clear(\@list)

Clears parameters from the session object.

With no parameters, all fields are cleared. If passed a single parameter or a
reference to an array, only the named parameters are cleared.

=head2 flush()

Synchronizes data in memory with the copy serialized by the driver. Call flush()
if you need to access the session from outside the current session object. You should
call flush() sometime before your program exits.

As a last resort, CGI::Session will automatically call flush for you just
before the program terminates or session object goes out of scope. Automatic
flushing has proven to be unreliable, and in some cases is now required
in places that worked with CGI::Session 3.x. See L<A Warning about Auto-flushing>.

Always explicitly calling C<flush()> on the session before the
program exits is recommended. For extra safety, call it immediately after
every important session update.

Also see L<A Warning about Auto-flushing>

=head2 atime()

Read-only method. Returns the last access time of the session in seconds from epoch.

=head2 ctime()

Read-only method. Returns the time when the session was first created in seconds from epoch.

=head2 expire()

=head2 expire($time)

=head2 expire($param, $time)

Sets expiration interval relative to L<atime()|/"atime()">.

If used with no arguments, returns the expiration interval if it was ever set. If no expiration was ever set, returns undef. For backwards compatibility, a method named C<etime()> does the same thing.

Second form sets an expiration time. This value is checked when previously stored session is asked to be retrieved, and if its expiration interval has passed, it will be expunged from the disk immediately. Passing 0 cancels expiration.

By using the third syntax you can set the expiration interval for a particular
session parameter, say I<~logged-in>. This would cause the library call clear()
on the parameter when its time is up. Note it only makes sense to set this value to
something I<earlier> than when the whole session expires.  Passing 0 cancels expiration.

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
            $self->_set_value('_SESSION_ETIME', undef);
        }
        # set the expiration to this time
        else {
            $self->_set_value('_SESSION_ETIME', $self->_str2seconds( $time ) );
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

=head2 is_new()

Returns true only for a brand new session.

=head2 is_expired()

Tests whether session initialized using L<load()|/"load"> is to be expired. This method works only on sessions initialized with load():

    $s = CGI::Session->load() or die CGI::Session->errstr;
    if ( $s->is_expired ) {
        die "Your session expired. Please refresh";
    }
    if ( $s->is_empty ) {
        $s = $s->new() or die $s->errstr;
    }


=head2 is_empty()

Returns true for sessions that are empty. It's preferred way of testing whether requested session was loaded successfully or not:

    $s = CGI::Session->load($sid);
    if ( $s->is_empty ) {
        $s = $s->new();
    }

Actually, the above code is nothing but waste. The same effect could've been achieved by saying:

    $s = CGI::Session->new( $sid );

L<is_empty()|/"is_empty"> is useful only if you wanted to catch requests for expired sessions, and create new session afterwards. See L<is_expired()|/"is_expired"> for an example.

=head2 delete()

Sets the objects status to be "deleted".  Subsequent read/write requests on the
same object will fail.  To physically delete it from the data store you need to call L<flush()|/"flush()">.
CGI::Session attempts to do this automatically when the object is being destroyed (usually as
the script exits), but see L<A Warning about Auto-flushing>.

=head2 find( \&code )

=head2 find( $dsn, \&code )

=head2 find( $dsn, \&code, \%dsn_args )

Experimental feature. Executes \&code for every session object stored on disk, passing initialized CGI::Session object as the first argument of \&code. Useful for housekeeping purposes, such as for removing expired sessions.

The following line, for instance, will remove sessions already expired, but which are still on disk:

    CGI::Session->find( sub {} );

Notice, above \&code didn't have to do anything, because load(), which is called to initialize sessions inside find(), will automatically remove expired sessions. Following example will remove all the objects that are 10+ days old:

    CGI::Session->find( \&purge );
    sub purge {
        my ($session) = @_;
        next if $session->is_empty;    # <-- already expired?!
        if ( ($session->ctime + 3600*240) <= time() ) {
            $session->delete();
            $session->flush(); # Recommended practice says use flush() after delete().
        }
    }

B<Note>: find will not change the modification or access times on the sessions it returns.

Explanation of the 3 parameters to C<find()>:

=over 4

=item $dsn

This is the DSN (Data Source Name) used by CGI::Session to control what type of
sessions you previously created and what type of sessions you now wish method
C<find()> to pass to your callback.

The default value is defined above, in the docs for method C<new()>, and is
'driver:file;serializer:default;id:md5'.

Do not confuse this DSN with the DSN arguments mentioned just below, under \%dsn_args.

=item \&code

This is the callback provided by you (i.e. the caller of method C<find()>)
which is called by CGI::Session once for each session found by method C<find()>
which matches the given $dsn.

There is no default value for this coderef.

When your callback is actually called, the only parameter is a session. If you
want to call a subroutine you already have with more parameters, you can
achieve this by creating an anonymous subroutine that calls your subroutine
with the parameters you want. For example:

    CGI::Session->find($dsn, sub { my_subroutine( @_, 'param 1', 'param 2' ) } );
    CGI::Session->find($dsn, sub { $coderef->( @_, $extra_arg ) } );

Or if you wish, you can define a sub generator as such:

    sub coderef_with_args {
        my ( $coderef, @params ) = @_;
        return sub { $coderef->( @_, @params ) };
    }

    CGI::Session->find($dsn, coderef_with_args( $coderef, 'param 1', 'param 2' ) );

=item \%dsn_args

If your $dsn uses file-based storage, then this hashref might contain keys such as:

    {
        Directory => Value 1,
        NoFlock   => Value 2,
        UMask     => Value 3
    }

If your $dsn uses db-based storage, then this hashref contains (up to) 3 keys, and looks like:

    {
        DataSource => Value 1,
        User       => Value 2,
        Password   => Value 3
    }

These 3 form the DSN, username and password used by DBI to control access to your database server,
and hence are only relevant when using db-based sessions.

The default value of this hashref is undef.

=back

B<Note:> find() is meant to be convenient, not necessarily efficient. It's best suited in cron scripts.

=head2 name($new_name)

The $new_name parameter is optional. If supplied it sets the query or cookie parameter name to be used.

It defaults to I<$CGI::Session::NAME>, which defaults to I<CGISESSID>.

You are strongly discouraged from using the global variable I<$CGI::Session::NAME>, since it is
deprecated (as are all global variables) and will be removed in a future version of this module.

Return value: The current query or cookie parameter name.

=head1 MISCELLANEOUS METHODS

=head2 remote_addr()

Returns the remote address of the user who created the session for the first time. Returns undef if variable REMOTE_ADDR wasn't present in the environment when the session was created.

=cut

sub remote_addr {   return $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR}   }

=pod

=head2 errstr()

Class method. Returns last error message from the library.

=head2 dump()

Returns a dump of the session object. Useful for debugging purposes only.

=head2 header()

A wrapper for a CGI-like header() method. Calling this method
is equivalent to something like this:

    $cookie = CGI::Cookie->new(-name=>$session->name, -value=>$session->id);
    print $cgi->header(-cookie=>$cookie, @_);

You can minimize the above to:

    print $session->header();

It will retrieve the name of the session cookie from C<< $session->name() >> which defaults to the deprecated global variable C<$CGI::Session::NAME>.

If you want to use a different name for your session cookie, do something like this before creating a session object:

    CGI::Session->name("MY_SID");
    $session = CGI::Session->new(undef, $cgi, \%attrs);

Now, $session->header() uses "MY_SID" as the name for the session cookie. For all additional options that can
be passed, see the C<header()> docs in C<CGI>.

=head2 query()

Returns query object associated with current session object. Default query object class is C<CGI>.

This can be overridden in the call to L<new()|/"new()"> or L<load()|/"load()"> with
{query_class => 'Some::Class'} as the value for \%session_params.

=head2 DESTROY()

When the session object goes out of scope, Perl calls the C<DESTROY()> method.

This calls L<flush()|/"flush()">.

=head2 DEPRECATED METHODS

These methods exist solely for for compatibility with CGI::Session 3.x.

=head3 close()

Closes the session. Using flush() is recommended instead, since that's exactly what a call
to close() does now.

=head1 DISTRIBUTION

CGI::Session consists of several components such as L<drivers|"DRIVERS">, L<serializers|"SERIALIZERS"> and L<id generators|"ID GENERATORS">. This section lists what is available.

=head2 DRIVERS

The following drivers are included in the standard distribution:

=over 4

=item db_file

C<CGI::Session::Driver::db_file> - for storing session data in BerkelyDB. Requires: C<DB_File>.

=item file

C<CGI::Session::Driver::file> - default driver for storing session data in plain files.

=item mysql

C<CGI::Session::Driver::mysql> - for storing session data in MySQL tables. Requires C<DBI> and C<DBD::mysql>.

=item postgresql

C<CGI::Session::Driver::postgresql> - for storing session data in PostgreSQL tables. Requires C<DBI> and C<DBD::Pg>.

=item sqlite

C<CGI::Session::Driver::sqlite> - for storing session data in SQLite. Requires C<DBI> and C<DBD::SQLite>

=back

Other drivers are available from CPAN.

=head2 SERIALIZERS

The following serializers are included in the standard distribution:

=over 4

=item default

C<CGI::Session::Serialize::default> - default data serializer. Uses standard C<Data::Dumper>.

=item freezethaw

C<CGI::Session::Serialize::freezethaw> - serializes data using C<FreezeThaw>.

=item storable

C<CGI::Session::Serialize::storable> - serializes data using C<Storable>.

=back

Other drivers are available from CPAN.

=head2 ID GENERATORS

The following ID generators are included in the standard distribution:

=over 4

=item incr

C<CGI::Session::ID::incr> - generates incremental session ids.

=item md5

C<CGI::Session::ID::md5> - generates 32 character long hexadecimal string. Requires C<Digest::MD5>.

=item static

C<CGI::Session::ID::static> - generates static session ids.

=back

=head1 A Warning about Auto-flushing

Auto-flushing can be unreliable for the following reasons. Explict flushing
after key session updates is recommended.

=over 4

=item If the C<DBI> handle goes out of scope before the session variable

For database-stored sessions, if the C<DBI> handle has gone out of scope before
the auto-flushing happens, auto-flushing will fail.

=item Circular references

If the calling code contains a circular reference, it's possible that your
C<CGI::Session> object will not be destroyed until it is too late for
auto-flushing to work. You can find circular references with a tool like
L<Devel::Cycle>.

In particular, these modules are known to contain circular references which
lead to this problem:

=over 4

=item CGI::Application::Plugin::DebugScreen V 0.06

=item CGI::Application::Plugin::ErrorPage before version 1.20

=back

=item Signal handlers

If your application may receive signals, there is an increased chance that the
signal will arrive after the session was updated but before it is auto-flushed
at object destruction time.

=back

=head1 A Warning about UTF8

You are strongly encouraged to refer to, at least, the first of these articles, for help with UTF8.

L<http://en.wikibooks.org/wiki/Perl_Programming/Unicode_UTF-8>

L<http://perl.bristolbath.org/blog/lyle/2008/12/giving-cgiapplication-internationalization-i18n.html>

L<http://metsankulma.homelinux.net/cgi-bin/l10n_example_4/main.cgi>

L<http://rassie.org/archives/247>

L<http://www.di-mgt.com.au/cryptoInternational2.html>

Briefly, these are the issues:

=over 4

=item The file containing the source code of your program

Consider "use utf8;" or "use encoding 'utf8';".

=item Influencing the encoding of the program's input

Use:

    binmode STDIN, ":encoding(utf8)";.

Of course, the program can get input from other sources, e.g. HTML template files, not just STDIN.

=item Influencing the encoding of the program's output

Use:

    binmode STDOUT, ":encoding(utf8)";

When using CGI.pm, you can use $q->charset('UTF-8'). This is the same as passing 'UTF-8' to CGI's C<header()> method. 

Alternately, when using CGI::Session, you can use $session->header(charset => 'utf-8'), which will be
passed to the query object's C<header()> method. Clearly this is preferable when the query object might not be
of type CGI.

See L</header()> for a fuller discussion of the use of the C<header()> method in conjunction with cookies.

=back

=head1 TRANSLATIONS

This document is also available in Japanese.

=over 4

=item o

Translation based on 4.14: http://digit.que.ne.jp/work/index.cgi?Perldoc/ja

=item o

Translation based on 3.11, including Cookbook and Tutorial: http://perldoc.jp/docs/modules/CGI-Session-3.11/

=back

=head1 CREDITS

CGI::Session evolved to what it is today with the help of following developers. The list doesn't follow any strict order, but somewhat chronological. Specifics can be found in F<Changes> file

=over 4

=item Andy Lester

=item Brian King E<lt>mrbbking@mac.comE<gt>

=item Olivier Dragon E<lt>dragon@shadnet.shad.caE<gt>

=item Adam Jacob E<lt>adam@sysadminsith.orgE<gt>

=item Igor Plisco E<lt>igor@plisco.ruE<gt>

=item Mark Stosberg

=item Matt LeBlanc E<lt>mleblanc@cpan.orgE<gt>

=item Shawn Sorichetti

=item Ron Savage

=item Rhesa Rozendaal

He suggested Devel::Cycle to help debugging.

=back

Also, many people on the CGI::Application and CGI::Session mailing lists have contributed ideas and
suggestions, and battled publicly with bugs, all of which has helped.

=head1 COPYRIGHT

Copyright (C) 2001-2005 Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt>. All rights reserved.
This library is free software. You can modify and or distribute it under the same terms as Perl itself.

=head1 PUBLIC CODE REPOSITORY

You can see what the developers have been up to since the last release by
checking out the code repository. You can browse the git repository from here:

 http://github.com/cromedome/cgi-session/tree/master

or check out the code with:

 git clone git://github.com/cromedome/cgi-session.git

=head1 SUPPORT

If you need help using CGI::Session, ask on the mailing list. You can ask the
list by sending your questions to cgi-session-user@lists.sourceforge.net .

You can subscribe to the mailing list at https://lists.sourceforge.net/lists/listinfo/cgi-session-user .

Bug reports can be submitted at http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CGI-Session

=head1 AUTHOR

Sherzod Ruzmetov C<sherzodr@cpan.org>

Mark Stosberg became a co-maintainer during the development of 4.0. C<markstos@cpan.org>.

Ron Savage became a co-maintainer during the development of 4.30. C<rsavage@cpan.org>.

If you would like support, ask on the mailing list as describe above. The
maintainers and other users are subscribed to it.

=head1 SEE ALSO

To learn more both about the philosophy and CGI::Session programming style,
consider the following:

=over 4

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual. Also includes library architecture and driver specifications.

=item *

We also provide mailing lists for CGI::Session users. To subscribe to the list
or browse the archives visit
https://lists.sourceforge.net/lists/listinfo/cgi-session-user

=item * B<RFC 2109> - The primary spec for cookie handing in use, defining the  "Cookie:" and "Set-Cookie:" HTTP headers.
Available at L<http://www.ietf.org/rfc/rfc2109.txt>. A newer spec, RFC 2965 is meant to obsolete it with "Set-Cookie2"
and "Cookie2" headers, but even of 2008, the newer spec is not widely supported. See L<http://www.ietf.org/rfc/rfc2965.txt>

=item *

L<Apache::Session|Apache::Session> - an alternative to CGI::Session.

=back

=cut

1;

