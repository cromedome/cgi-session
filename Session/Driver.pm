package CGI::Session::Driver;

use strict;
use Carp "croak";
use CGI::Session::ErrorHandler;
use Data::Dumper;
use vars qw( $VERSION @ISA );

$VERSION = "0.01";
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
