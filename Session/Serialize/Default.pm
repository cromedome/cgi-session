package CGI::Session::Serialize::Default;

# $Id$ 
use strict;
use Safe;
use Data::Dumper;

use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;


sub freeze {
    my ($self, $data) = @_;
    
    my $d = Data::Dumper->new([$data], ["data"]);
    # To disable indenting to create the most compact string.
    $d->Indent(0);  
    
    # to save a little bit of space
    $d->Terse(1);   

    # to save a little more space :-)
    $d->Quotekeys(0);
    
    return $d->Dump();
}



sub thaw {
    my ($self, $string) = @_;    

    # To make -T happy
    my ($safe_string) = $string =~ m/^(.*)$/;

    my $cpt = Safe->new();
    return $cpt->reval($safe_string);
}


1;

=pod

=head1 NAME

CGI::Session::Serialize::Default - default serializer for CGI::Session

=head1 DESCRIPTION

This library is used by CGI::Session driver to serialize session data before storing
it in disk. 

=head1 METHODS

=over 4

=item freeze()

receives two arguments. First is the CGI::Session driver object, the second is the data to be
stored passed as a reference to a hash. Should return true to indicate success, undef otherwise, 
passing the error message with as much details as possible to $self->error()

=item thaw()

receives two arguments. First being CGI::Session driver object, the second is the string
to be deserialized. Should return deserialized data structure to indicate successs. undef otherwise,
passing the error message with as much details as possible to $self->error().

=back

=head1 WARNING

If you want to be able to store objects, consider using L<CGI::Session::Serialize::Storable> or
L<CGI::Session::Serialize::FreezeThaw> instead.

=head1 COPYRIGHT

Copyright (C) 2002 Sherzod Ruzmetov. All rights reserved.

This library is free software. It can be distributed under the same terms as Perl itself. 

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

All bug reports should be directed to Sherzod Ruzmetov <sherzodr@cpan.org>. 

=head1 SEE ALSO

L<CGI::Session>
L<CGI::Session::Serialize::Storable>
L<CGI::Session::Serialize::FreezeThaw>

=cut

