package CGI::Session::Serialize::default;

# $Id$ 

use strict;
#use diagnostics;

use Safe;
use Data::Dumper;

$CGI::Session::Serialize::default::VERSION = '1.4';


sub freeze {
    my ($class, $data) = @_;
    
    my $d = new Data::Dumper([$data], ["D"]);
    $d->Indent( 0 );
    $d->Purity( 0 );
    $d->Useqq( 0 );
    $d->Deepcopy( 1 );
    $d->Quotekeys( 0 );
    $d->Terse( 0 );
    return $d->Dump();
}

sub thaw {
    my ($class, $string) = @_;

    # To make -T happy
    my ($safe_string) = $string =~ m/^(.*)$/;
    Safe->new()->reval( $safe_string );
}


1;

__END__;

=pod

=head1 NAME

CGI::Session::Serialize::default - Default CGI::Session serializer

=head1 DESCRIPTION

This library is used by CGI::Session driver to serialize session data before storing
it in disk.

All the methods are called as class methods.

=head1 METHODS

=over 4

=item freeze($class, \%hash)

Receives two arguments. First is the class name, the second is the data to be serialized.
Should return serialized string on success, undef on failure. Error message should be set using
C<set_error()|CGI::Session::ErrorHandler/"set_error()">

=item thaw($class, $string)

Received two arguments. First is the class name, second is the I<frozen> data string. Should return
thawed data structure on success, undef on failure. Error message should be set 
using C<set_error()|CGI::Session::ErrorHandler/"set_error()">

=back

=head1 WARNING

May not be able to freeze/thaw complex objects. For that consider L<storable|CGI::Session::Serialize::storable>
or L<freezethaw|CGI::Session::Serialize::freezethaw>

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut

