package CGI::Session;

# $Id$

use strict;
use Carp 'confess';
use AutoLoader 'AUTOLOAD';

use vars qw($VERSION $errstr $IP_MATCH $COOKIE);

($VERSION)  = '$Revision$' =~ m/Revision:\s*(\S+)/;
$COOKIE     = 'CGISESSID';

# import() - we do not import anything into the callers
# namespace, however, we enable the user to specify
# hooks at compile time
sub import {
    my $class = shift;
    @_ or return;
    for ( my $i=0; $i < @_; $i++ ) {
        $IP_MATCH = ( $_[$i] eq '-ip_match' ) and next;        
    }
}


# Session _status flags
sub SYNCED   () { 0 }
sub MODIFIED () { 1 }
sub DELETED  () { 2 }


# new() - constructor.
# Returns respective driver object
sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _options    => [ @_ ],
        _data       => undef,
        _status     => MODIFIED,
    };

    bless ($self, $class);
    $self->_validate_driver() && $self->_init() or return;
    return $self;
}




# DESTROY() - destructor.
# Flushes the memory, and calls driver's teardown()
sub DESTROY {
    my $self = shift;

    $self->flush();
    $self->can('teardown') && $self->teardown();
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
                "At least one method('$method') is missing";
        }
    }
    return 1;
}




# _init() - object initialializer.
# Decides between _init_old_session() and _init_new_session()
sub _init {
    my $self = shift;

    my $claimed_id = undef;
    my $arg = $self->{_options}->[0];
    if ( defined ($arg) && ref($arg) ) {
        if ( $arg->isa('CGI') ) {            
            $claimed_id = $arg->cookie($COOKIE) || $arg->param($COOKIE) || undef;
        } elsif ( ref($arg) eq 'CODE' ) {
            $claimed_id = $arg->() || undef;

        }
    } else {
        $claimed_id = $arg;
    }

    if ( defined $claimed_id ) {
        my $rv = $self->_init_old_session($claimed_id);

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

    my $options = $self->{_options} || [];
    my $data = $self->retrieve($claimed_id, $options);

    # Session was initialized successfully
    if ( defined $data ) {

        $self->{_data} = $data;

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
        $self->{_data}->{_session_atime} = time();

        # Marking the session as modified
        $self->{_status} = MODIFIED;

        return 1;
    }
    return undef;
}





sub _ip_matches {
    return ( $_[0]->{_data}->{_session_remote_addr} eq $ENV{REMOTE_ADDR} );
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
    my $exp_list = $self->{_data}->{_session_expire_list} || {};
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

    $self->{_data} = {
        _session_id => $self->generate_id(),
        _session_ctime => time(),
        _session_atime => time(),
        _session_etime => undef,
        _session_remote_addr => $ENV{REMOTE_ADDR} || undef,
        _session_expire_list => { },
    };

    $self->{_status} = MODIFIED;

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

    return $self->{_data}->{_session_id};
}



# param() - accessor method. Reads and writes
# session parameters ( $self->{_data} ). Decides
# between _get_param() and _set_param() accordingly.
sub param {
    my $self = shift;


    unless ( defined $_[0] ) {
        return keys %{ $self->{_data} };
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

    confess "param(): something smells fishy here. RTFM!";
}



# _set_param() - sets session parameter to the '_data' table
sub _set_param {
    my ($self, $key, $value) = @_;

    if ( $self->{_status} == DELETED ) {
        return;
    }

    # session parameters starting with '_session_' are
    # private to the class
    if ( $key =~ m/^_session_/ ) {
        return undef;
    }

    $self->{_data}->{$key} = $value;
    $self->{_status} = MODIFIED;

    return $value;
}




# _get_param() - gets a single parameter from the
# '_data' table
sub _get_param {
    my ($self, $key) = @_;

    if ( $self->{_status} == DELETED ) {
        return;
    }

    return $self->{_data}->{$key};
}


# flush() - flushes the memory into the disk if necessary.
# Usually called from within DESTROY() or close()
sub flush {
    my $self = shift;

    my $status = $self->{_status};

    if ( $status == MODIFIED ) {
        $self->store($self->id, $self->{_options}, $self->{_data});
        $self->{_status} = SYNCED;
    }

    if ( $status == DELETED ) {
        return $self->remove($self->id, $self->{_options});
    }

    $self->{_status} = SYNCED;

    return 1;
}






# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__






# dump() - dumps the session object using Data::Dumper
sub dump {
    my ($self, $file) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = 1;

    my $d = new Data::Dumper([$self], ["cgisession"]);

    if ( defined $file ) {
        unless ( open(FH, '<' . $file) ) {
            unless(open(FH, '>' . $file)) {
                $self->error("Couldn't open $file: $!");
                return undef;
            }
            print FH $d->Dump();
            unless ( close(FH) ) {
                $self->error("Couldn't dump into $file: $!");
                return undef;
            }
        }
    }

    return $d->Dump();
}



sub version {   return $VERSION()   }


# delete() - sets the '_status' session flag to DELETED,
# which flush() uses to decide to call remove() method on driver.
sub delete {
    my $self = shift;

    # If it was already deleted, make a confession!
    if ( $self->{_status} == DELETED ) {
        confess "delete attempt on deleted session";
    }

    $self->{_status} = DELETED;
}





# clear() - clears a list of parameters off the session's '_data' table
sub clear {
    my $self = shift;
    $class   = ref($class);

    my @params = ();
    if ( defined $_[0] ) {
        unless ( ref($_[0]) eq 'ARRAY' ) {
            confess "Usage: $class->clear([\@array])";
        }
        @params = @{ $_[0] };

    } else {
        @params = $self->param();

    }

    my $n = 0;
    for ( @params ) {
        /^_session_/ and next;
        # If this particular parameter has an expiration ticker,
        # remove it.
        if ( $self->{_data}->{_session_expire_list}->{$_} ) {
            delete ( $self->{_data}->{_session_expire_list}->{$_} );
        }
        delete ($self->{_data}->{$_}) && ++$n;
    }

    # Set the session '_status' flag to MODIFIED
    $self->{_status} = MODIFIED;

    return $n;
}


# save_param() - copies a list of third party object parameters
# into CGI::Session object's '_data' table
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
# such as CGI, into CGI::Session's '_data' table
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
        confess "_session_atime - read-only value";
    }

    return $self->{_data}->{_session_atime};
}


# ctime() - returns session creation time
sub ctime {
    my $self = shift;

    if ( defined @_ ) {
        confess "_session_atime - read-only value";
    }

    return $self->{_data}->{_session_ctime};
}


# expire() - sets/returns session/parameter expiration ticker
sub expire {
    my $self = shift;

    unless ( @_ ) {
        return $self->{_data}->{_session_etime};
    }

    if ( @_ == 1 ) {
        return $self->{_data}->{_session_etime} = _time_alias( $_[0] );
    }

    # If we came this far, we'll simply assume user is trying
    # to set an expiration date for a single session parameter.
    my ($param, $etime) = @_;

    # Let's check if that particular session parameter exists
    # in the '_data' table. Otherwise, return now!
    defined ($self->{_data}->{$param} ) || return;

    if ( $etime == -1 ) {
        delete $self->{_data}->{_session_expire_list}->{$param};
        return;
    }

    $self->{_data}->{_session_expire_list}->{$param} = _time_alias( $etime );
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
        d           => 3600 * 24,
        w           => 3600 * 24 * 7,
        M           => 3600 * 24 * 30,
        y           => 3600 * 24 * 365,
    );

    my ($koef, $d) = $str =~ m/([+-]?\d+)(\w)/;

    if ( defined($koef) && defined($d) ) {
        return $koef * $time_map{$d};
    }
}


# remote_addr() - returns ip address of the session
sub remote_addr {
    my $self = shift;

    return $self->{_data}->{_session_remote_addr};
}


# param_hashref() - returns parameters as a reference to a hash
sub param_hashref {
    my $self = shift;

    return $self->{_data};
}


# $Id$
