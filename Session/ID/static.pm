package CGI::Session::ID::static;

use strict;
use Carp 'croak';
use vars qw($VERSION);

($VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;

# Preloaded methods go here.

sub generate_id {
	my ($self, $args, $claimed_id ) = @_;

    unless ( defined $claimed_id ) {
        croak "'CGI::Session::ID::Static::generate_id()' requires static id";
    }

    return $claimed_id;
}

1;
__END__

=head1 NAME

CGI::Session::ID::Static - CGI::Session ID Driver for Caching 

=head1 SYNOPSIS

    use CGI::Session;

    $session = new CGI::Session("driver:SomeDriver;id:Static", "my_id", \%attrs);

=head1 DESCRIPTION

CGI::Session::ID::Static is used to generate consistent, static session
ID's.  The only time you would really want to do this is when you need
to use CGI::Session for caching information, most likely the results
of an expensive database query.  

Unlike the other ID drivers, this one requires that you provide an ID
when creating the session object; if you pass it an undefined value, it
will cause an error.

=head1 COPYRIGHT

Copyright (C) 2002 Adam Jacob <adam@sysadminsith.org>, 
Sherzod Ruzmetov <sherzodr@cpan.org>. All rights reserved.

This library is free software. You can modify and distribute it under the same
terms as Perl itself.

=head1 AUTHORS

Adam Jacob <adam@sysadminsith.org>, 
Sherzod Ruzmetov <sherzodr@cpan.org>

Feedbacks, suggestions and patches are welcome.

=head1 SEE ALSO

=over 4

=item *

L<Incr|CGI::Session::ID::MD5> - Random 32 character long hexidecimal ID generator

=item *

L<Incr|CGI::Session::ID::Incr> - Auto Incremental ID generator

=item *

L<CGI::Session|CGI::Session> - CGI::Session manual

=item *

L<CGI::Session::Tutorial|CGI::Session::Tutorial> - extended CGI::Session manual

=item *

L<CGI::Session::CookBook|CGI::Session::CookBook> - practical solutions for real
life problems

=item *

B<RFC 2965> - "HTTP State Management Mechanism" found at
ftp://ftp.isi.edu/in-notes/rfc2965.txt

=item *

L<CGI|CGI> - standard CGI library

=item *

L<Apache::Session|Apache::Session> - another fine alternative to CGI::Session

=back

=cut
