package CGI::Session::Driver::postgresql;

# $Id$

# CGI::Session::Driver::postgresql - PostgreSQL driver for CGI::Session
#
# Copyright (C) 2002 Cosimo Streppone, cosimo@cpan.org
# This module is based on CGI::Session::Driver::mysql module
# by Sherzod Ruzmetov, original author of CGI::Session modules
# and CGI::Session::Driver::mysql driver.

use strict;
use Carp "croak";

use CGI::Session::Driver::DBI;
use DBD::Pg qw(PG_BYTEA PG_TEXT);

$CGI::Session::Driver::postgresql::VERSION = '2.3';
@CGI::Session::Driver::postgresql::ISA     = qw( CGI::Session::Driver::DBI );


sub init {
    my $self = shift;
    my $ret = $self->SUPER::init(@_);
    if (defined $self->{ColumnType}) {
        no warnings "numeric";
        return $ret if $self->{ColumnType} == PG_BYTEA || $self->{ColumnType} == PG_TEXT;
        $self->{ColumnType} = lc(substr($self->{ColumnType},0,1)) eq 'b' ? PG_BYTEA : PG_TEXT;
    } else {
        $self->{ColumnType} = PG_TEXT;
    }
    return $ret;
}

sub store {
    my $self = shift;
    my ($sid, $datastr) = @_;
    croak "store(): usage error" unless $sid && $datastr;

    my $dbh = $self->{Handle};
    my $type = $self->{ColumnType};

    if ($type == PG_TEXT && $datastr =~ tr/\x00//) {
        croak "Unallowed characters used in session data. Please see CGI::Session::Driver::postgresql ".
            "for more information about null characters in text columns.";
    }

    my $sth = $dbh->prepare("SELECT id FROM " . $self->table_name . " WHERE id=?");
    unless ( defined $sth ) {
        return $self->set_error( "store(): \$sth->prepare failed with message " . $dbh->errstr );
    }

    $sth->execute( $sid ) or return $self->set_error( "store(): \$sth->execute failed with message " . $dbh->errstr );
    if ( $sth->fetchrow_array ) {
        __ex_and_ret($dbh,"UPDATE " . $self->table_name . " SET a_session=? WHERE id=?",$datastr,$sid, $type)
            or return $self->set_error( "store(): serialize to db failed " . $dbh->errstr );
    } else {
        __ex_and_ret($dbh,"INSERT INTO " . $self->table_name . " (a_session,id) VALUES(?, ?)",$datastr, $sid, $type)
            or return $self->set_error( "store(): serialize to db failed " . $dbh->errstr );
    }
    return 1;
}

sub __ex_and_ret {
    my ($dbh,$sql,$datastr,$sid,$type) = @_;
    # fix rt #18183
    local $@;
    eval {
        my $sth = $dbh->prepare($sql) or return 0;
        $sth->bind_param(1,$datastr,{ pg_type => $type }) or return 0;
        $sth->bind_param(2,$sid) or return 0;
        $sth->execute() or return 0;
    };
    return ! $@;
}

1;

=pod

=head1 NAME

CGI::Session::Driver::postgresql - PostgreSQL driver for CGI::Session

=head1 SYNOPSIS

    use CGI::Session;
    $session = new CGI::Session("driver:PostgreSQL", undef, {Handle=>$dbh});

=head1 DESCRIPTION

CGI::Session::PostgreSQL is a L<CGI::Session|CGI::Session> driver to store session data in a PostgreSQL table.

=head1 STORAGE

Before you can use any DBI-based session drivers you need to make sure compatible database table is created for CGI::Session to work with. Following command will produce minimal requirements in most SQL databases:

    CREATE TABLE sessions (
        id CHAR(32) NOT NULL PRIMARY KEY,
        a_session BYTEA NOT NULL
    );

and within your code use:

    use CGI::Session;
    $session = new CGI::Session("driver:PostgreSQL", undef, {Handle=>$dbh, ColumnType=>"binary"});

Please note the I<ColumnType> argument. PostgreSQL's text type has problems when trying to hold a null character. (Known as C<"\0"> in Perl, not to be confused with SQL I<NULL>). If you know there is no chance of ever having a null character in the serialized data, you can leave off the I<ColumnType> attribute. Using a I<BYTEA> column type and C<< ColumnType => 'binary' >> is recommended when using L<Storable|CGI::Session::Serialize::storable> as the serializer or if there's any possibility that a null value will appear in any of the serialized data.

For more details see L<CGI::Session::Driver::DBI|CGI::Session::Driver::DBI>, parent class.

Also see L<sqlite driver|CGI::Session::Driver::sqlite>, which exercises different method for dealing with binary data.

=head1 COPYRIGHT

Copyright (C) 2002 Cosimo Streppone. All rights reserved. This library is free software and can be modified and distributed under the same terms as Perl itself.

=head1 AUTHORS

Cosimo Streppone <cosimo@cpan.org>, heavily based on the CGI::Session::MySQL driver by Sherzod Ruzmetov, original author of CGI::Session.

Matt LeBlanc contributed significant updates for the 4.0 release.

=head1 LICENSING

For additional support and licensing see L<CGI::Session|CGI::Session>

=cut
