package CGI::Session::Driver::mysql;

# $Id$

use strict;
#use diagnostics;

use Carp;
use CGI::Session::Driver::DBI;

@CGI::Session::Driver::mysql::ISA       = qw( CGI::Session::Driver::DBI );
$CGI::Session::Driver::mysql::VERSION   = "2.01";

sub init {
    my $self = shift;
    if ( $self->{DataSource} && ($self->{DataSource} !~ /^dbi:mysql/i) ) {
        $self->{DataSource} = "dbi:mysql:database=" . $self->{DataSource};
    }
    return $self->SUPER::init();
}

sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my $dbh = $self->{Handle};
    $dbh->do("REPLACE INTO " . $self->table_name . " (id, a_session) VALUES(?, ?)", undef, $sid, $datastr)
        or return $self->set_error( "store(): \$dbh->do failed " . $dbh->errstr );
    return 1;
}

1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::mysql - CGI::Session driver for MySQL database

=head1 SYNOPSIS

    $s = new CGI::Session( "driver:mysql", $sid);
    $s = new CGI::Session( "driver:mysql", $sid, { DataSource  => 'dbi:mysql:test',
                                                   User        => 'sherzodr',
                                                   Password    => 'hello' });
    $s = new CGI::Session( "driver:mysql", $sid, { Handle => $dbh } );

=head1 DESCRIPTION

B<mysql> stores session records in a MySQL table. For details see L<CGI::Session::Driver::DBI|CGI::Session::Driver::DBI>, its parent class.

=head2 DRIVER ARGUMENTS

B<mysql> driver supports all the arguments documented in CGI::Session::Driver::DBI. In addition, I<DataSource> argument can optionally leave leading "dbi:mysql:" string out:

    $s = new CGI::Session( "driver:mysql", $sid, {DataSource=>'shopping_cart'});
    # is the same as:
    $s = new CGI::Session( "driver:mysql", $sid, {DataSource=>'dbi:mysql:shopping_cart'});

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>.

=cut

