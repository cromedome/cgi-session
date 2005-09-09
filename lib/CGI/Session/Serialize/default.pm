package CGI::Session::Serialize::default;

# $Id$ 

use strict;
use Safe;
use Data::Dumper;
use CGI::Session::ErrorHandler;
use Scalar::Util qw(blessed reftype refaddr);
use Carp "croak";

@CGI::Session::Serialize::default::ISA = ( "CGI::Session::ErrorHandler" );
$CGI::Session::Serialize::default::VERSION = '1.5';


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
     my ($safe_string) = $string =~ m/^(.*)$/s;
     my $rv = Safe->new->reval( $safe_string );
    if ( my $errmsg = $@ ) {
        return $class->set_error("thaw(): couldn't thaw. $@");
    }
    __walk($rv);
    return $rv;
}

sub __walk {
    my %seen;
    my @filter = shift;
    
    while (defined(my $x = shift @filter)) {
        $seen{refaddr $x || ''}++ and next;
          
        my $r = reftype $x or next;
        if ($r eq "HASH") {
            push @filter, __scan(@{$x}{keys %$x});
        } elsif ($r eq "ARRAY") {
            push @filter, __scan(@$x);
        } elsif ($r eq "SCALAR" || $r eq "REF") {
            push @filter, __scan($$x);
        }
    }
}

sub __scan {
    for (@_) {
        if (blessed $_) {
            if (overload::Overloaded($_)) {
                my $r = reftype $_;
                if ($r eq "HASH") {
                    $_ = bless { %$_ }, ref $_;
                } elsif ($r eq "ARRAY") {
                    $_ = bless [ @$_ ], ref $_;
                } elsif ($r eq "SCALAR" || $r eq "REF") {
                    $_ = bless \do{my $o = $$_},ref $_;
                } else {
                    croak "Do not know how to reconstitute blessed object of base type $r";
                }
            } else {
                bless $_, ref $_;
            }
        }
    }
    return @_;
}


1;

__END__;

=pod

=head1 NAME

CGI::Session::Serialize::default - Default CGI::Session serializer

=head1 DESCRIPTION

This library is used by CGI::Session driver to serialize session data before storing it in disk.

All the methods are called as class methods.

=head1 METHODS

=over 4

=item freeze($class, \%hash)

Receives two arguments. First is the class name, the second is the data to be serialized. Should return serialized string on success, undef on failure. Error message should be set using C<set_error()|CGI::Session::ErrorHandler/"set_error()">

=item thaw($class, $string)

Received two arguments. First is the class name, second is the I<frozen> data string. Should return thawed data structure on success, undef on failure. Error message should be set using C<set_error()|CGI::Session::ErrorHandler/"set_error()">

=back

=head1 WARNING

May not be able to freeze/thaw complex objects. For that consider L<storable|CGI::Session::Serialize::storable> or L<freezethaw|CGI::Session::Serialize::freezethaw>

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut

