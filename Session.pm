package CGI::Session;

# $Id$

use strict;
use Carp 'croak';
use AutoLoader 'AUTOLOAD';

use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;


sub SYNCED   () { return 0 }
sub MODIFIED () { return 1 }
sub DELETED  () { return 2 }









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





sub DESTROY {
    my $self = shift;

    $self->flush() && $self->teardown();
    
}




sub _validate_driver {
    my $self = shift;

    my @required = qw(store retrieve remove generate_id);

    for my $method ( @required ) {
        unless ( $self->can($method) ) {
            my $class = ref($self);
            croak "$class doesn't seem to be a valid CGI::Session driver. " . 
                "At least '$method' method is missing";
        }
    }

    return 1;
}





sub _init {
    my $self = shift;

    my $claimed_id = $self->{_options}->[0];

    if ( defined $claimed_id ) {
        $self->_init_old_session($claimed_id);

        unless ( defined $self->{_data} ) {
            return $self->_init_new_session();
        }
        return 1;
    }
    return $self->_init_new_session();
}





sub _init_old_session {
    my ($self, $claimed_id) = @_;

    my $options = $self->{_options} || [];
    my $data = $self->retrieve($claimed_id, $options);

    if ( defined $data ) {
        $self->{_data} = $data;
        $self->{_data}->{_session_atime} = time();
        $self->{_status} = MODIFIED,
        return 1;
    }

    return undef;
}






sub _init_new_session {
    my $self = shift;

    $self->{_data} = {
        _session_id => $self->generate_id(),
        _session_ctime => time(),
        _session_atime => time(),
        _session_etime => undef,
        _session_remote_addr => $ENV{REMOTE_ADDR} || undef,
    };

    $self->{_status} = MODIFIED;

    return 1;
}





sub id {
    my $self = shift;

    return $self->{_data}->{_session_id};
}




sub param {
    my $self = shift;

    if ( $self->{_status} == DELETED ) {
        croak "read attempt on deleted session  ";
    }

    unless ( @_ ) {
        return keys %{$self->{_data}};
    }

    if ( @_ == 1 ) {
        return $self->get_param(@_);
    }

    # If it has more than one arguments, let's try to figure out
    # what the caller is trying to do, since our tricks are endless ;-)
    my $arg = {
        -name   => undef,
        -value  => undef,
        @_,
    };

    if ( defined($arg->{'-name'}) && defined($arg->{'-value'}) ) {
        return $self->set_param($arg->{'-name'}, $arg->{'-value'});
    
    }

    if ( defined $arg->{'-name'} ) {
        return $self->get_param( $arg->{'-name'} );
    }

    if ( @_ == 2 ) {
        return $self->set_param(@_);
    }

    unless ( @_ % 2 ) {
        my $n = 0;
        my %args = @_;
        while ( my ($key, $value) = each %args ) {
            $self->set_param($key, $value) && ++$n;
        }
        return $n;
    }
    
    croak "param(): something smells fishy here. RTFM!";
}




sub set_param {
    my ($self, $key, $value) = @_;

    if ( $self->{_status} == DELETED ) {
        croak "read attempt on deleted session";
    }

    $self->{_data}->{$key} = $value;
    $self->{_status} = MODIFIED;

    return $value;    
}





sub get_param {
    my ($self, $key) = @_;

    if ( $self->{_status} == DELETED ) {
        croak "read attempt on deleted session";
    }

    return $self->{_data}->{$key};
}



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

    return 1;
}






# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

CGI::Session - Perl extension for blah blah blah

=head1 SYNOPSIS

  use CGI::Session;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for CGI::Session, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.


=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 SEE ALSO

L<perl>.

=cut


sub dump {
    my $self = shift;

    require Data::Dumper;
    my $d = new Data::Dumper([$self->{_data}], ["cgisession"]);

    return $d->Dump();
}








sub version {
    return $VERSION;
}










sub delete {
    my $self = shift;

    if ( $self->{_status} == DELETED ) {
        croak "delete attempt on deleted session";
    }

    $self->{_status} = DELETED;
}






sub clear {
    my $self = shift;
    $class   = ref($class);

    my @params = ();
    if ( defined $_[0] ) {
        unless ( ref($_[0]) eq 'ARRAY' ) {
            croak "Usage: $class->clear([\@array])";
        }
        @params = @{ $_[0] };
    
    } else {
        @params = $self->params();

    }

    my $n = 0;
    for ( @params ) {
        /^_session/ and next;
        delete $self->{_data}->{$_} && ++$n;
    }

    $self->{_status} = MODIFIED;

    return $n;
}


