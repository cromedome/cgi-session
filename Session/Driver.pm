package CGI::Session::Driver;

# $Id$

use strict;
use diagnostics;

use Carp "croak";
use CGI::Session::ErrorHandler;
use vars qw( $VERSION @ISA );

$VERSION = "2.01";
@ISA     = qw(CGI::Session::ErrorHandler);


sub new {
    my $class = shift;
    my ($args) = @_;

    if ( $args ) {
        unless ( ref $args ) {
            croak "Invalid argument type passed to driver: " . Dumper($args);
        }
    } else {
        $args = {};
    }

    my $self = bless ($args, $class);
    return $self->init ? $self : undef;
}


sub init {}

sub retrieve {
    croak "retrieve(): " . ref($_[0]) . " failed to implement this method!";
}

sub store {
    croak "store(): " . ref($_[0]) . " failed to implement this method!";
}


sub remove {
    croak "remove(): " . ref($_[0]) . " failed to implement this method!";
}


sub dump {
    require Data::Dumper;
    my $d = Data::Dumper->new([$_[0]], [ref $_[0]]);
    return $d->Dump;
}


1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver - CGI::Session driver specifications

=head1 WARNING

Version 2.01 of CGI::Session's driver specification is B<NOT> backward compatible with previous specification. If you already have a 
driver developed to work with the previous version you're highly encouraged to upgrade your driver code to make it compatible with the
current version. Fortunately, current driver specs are a lot easier to adapt to.

If you need any help converting your driver to meet current specs, send me an e-mail. For support information see
L<CGI::Session|CGI::Session>

=head1 SYNOPSIS

    require CGI::Session::Driver;
    @ISA = qw( CGI::Session::Driver );

=head1 DESCRIPTION

CGI::Session::Driver is a base class for all CGI::Session's native drivers. It also documents driver specifications for those
willing to write drivers for different databases not currently supported by CGI::Session.

=head1 WHAT IS A DRIVER

Driver is a piece of code that helps CGI::Session library to talk to specific database engines, or storage mechanisms. To be more
precise, driver is a F<.pm> file that inherits from CGI::Session::Driver and defines L<retrieve()|/"retrieve()">, L<store()|/"store()"> and L<remove()|/"remove()"> methods.

=head2 BLUEPRINT

The best way of learning the specs is to look at a blueprint of a driver:

    package CGI::Session::Driver::your_driver_name;
    use strict;
    use base qw( CGI::Session::Driver CGI::Session::ErrorHandler );

    sub store {
        my ($self, $sid, $datastr) = @_;
        # Store $datastr, which is an already serialized string of data.
        # Return any true value on success, undef failure.
        # Set error message using $self->set_error()
    }
    
    sub retrieve {
        my ($self, $sid) = @_;
        # Return $datastr, which was previously stored using above store() method.
        # Return $datastr if $sid was found. Return 0 or "" if $sid doesn't exist
        # in the datastore. Return undef to indicate failure. Set error message
        # using $self->set_error()
    }

    sub remove {
        my ($self, $sid) = @_;
        # Remove storage associated for $sid. Return any true value indicating success,
        # or undef on failure. Set error message using $self->set_error()
    }

All the attributes passed as the second argument to CGI::Session's new() or load() methods will automatically
be made driver's object attributes. For example, if session object was initialized as following:

    $s = CGI::Session->new("driver:your_driver_name", undef, {Directory=>'/tmp/sessions'});

You can access value of 'Directory' from within your driver like so:

    sub store {
        my ($self, $sid, $datastr) = @_;
        my $dir = $self->{Directory};   # <-- in this example will be '/tmp/sessions'
    }

Optionally, you can define C<init()> method within your driver to do driver specific global initialization. C<init()> method
will be envoked only ones during the lifecycle of your driver, which is the same as the lifecycle of a session object.

For examples of C<init()> look into native CGI::Session drivers.

=head2 NOTES

=over 4

=item *

All driver F<.pm> files must be lowercase!

=item *

DBI-related drivers are better off using L<CGI::Session::Driver::DBI|CGI::Session::Driver::DBI> as base, but don't have to.

=back

=head1 LICENSING

For support and licensing information see L<CGI::Session|CGI::Session>.

=cut
