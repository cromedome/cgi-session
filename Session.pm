package CGI::Session;

# $Id$

use strict;
use warnings;

use AutoLoader qw(AUTOLOAD);

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

    $self->_init() or return;

    return $self;
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
    my $data = $self->retrieve($options, $claimed_id);

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
        _session_remote_addr => $ENV{REMOTE_ADDR} || undef
    };

    return 1;
}




sub id {
    my $self = shift;

    return $self->{_data}->{_session_id};
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
