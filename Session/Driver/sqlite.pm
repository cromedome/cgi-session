package CGI::Session::Driver::sqlite;

use strict;
use diagnostics;

use Carp;
use File::Spec;
use CGI::Session::Driver::DBI;
use vars qw( $VERSION @ISA $TABLE_NAME );

@ISA        = qw( CGI::Session::Driver::DBI );
$VERSION    = "2.01";
$TABLE_NAME = "sessions";


sub init {
    my $self = shift;

    return $self->SUPER::init() if $self->{Handle};
    $self->{DataSource} ||= File::Spec->catfile( File::Spec->tmpdir, 'sessions.sqlt' );

    unless ( $self->{DataSource} =~ /^dbi:sqlite/i ) {
        $self->{DataSource} = "dbi:SQLite:dbname=" . $self->{DataSource};
    }
    $self->{User} = $self->{Password} = "";
    return $self->SUPER::init();
}


1;

__END__;

=pod

=head1 NAME

CGI::Session::Driver::sqlite - CGI::Session driver for SQLite

=head1 SYNOPSIS

    $s = new CGI::Session("driver:sqlite", $sid);
    $s = new CGI::Session("driver:sqlite", $sid, {DataSource=>'/tmp/sessions.sqlt'});

=head1 DESCRIPTION

B<sqlite> driver will store session data in SQLite files using L<DBD::SQLite|DBD::SQLite> DBI driver.

=head1 DRIVER ARGUMENTS

Supported driver arguments are I<DataSource> and I<Handle>. B<At most> only one of these arguments can be
set while creating session object.

I<DataSource> should be in the form of C<dbi:SQLite:dbname=/path/to/db.sqlt>. If C<dbi:SQLite> is found to be
missing it will be prepended for you.

If I<Handle> is present it should be database handle ($dbh) returned by DBI->connect().

=head1 LICENSING

For support and licensing see L<CGI::Session|CGI::Session>

=cut

