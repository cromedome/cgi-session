package CGI::Session::Test;

# $Id$

use strict;
use CGI::Session::File;
use HTML::Template;
use base 'CGI::Application';

($CGI::Session::Test::VERSION) = '$Revision$' =~ m/Revision:\s*(\S+)/;




#---------- Initializing CGI::Session::Test object ------------------
sub setup {
    my $self = shift;

    $self->mode_param(\&parse_args);
    $self->start_mode('html');

    $self->run_modes(        
        html        => \&html,
        save_param  => \&save_param,
        dump        => \&dump,
        clear       => \&clear,
        delete      => \&delete,
    );
    
    $self->cgi_session();
}










sub parse_args {
    my ($cmd) = $ENV{PATH_INFO} =~ m!/cmd/-/([^?]+)!;
    return $cmd;
}


        





sub cgi_session {
    my $self = shift;

    if ( defined $self->param('cgi_session') ) {
        return $self->param('cgi_session');
    }
    
    my $cgi = $self->query();
    my $sid = $cgi->cookie('CGISESSID') || $cgi->param('CGISESSID') || undef;
    
    my $session = new CGI::Session::File($sid, {Directory=>$self->param('temp_folder')})
                    or die $CGI::Session::errstr;
    $self->param(cgi_session => $session);
    return $session;
}









sub load_tmpl {
    my ($self, $file, $params) = @_;

    $params ||= {};

    my $cgi = $self->query();
    my $session = $self->cgi_session();

    my $template = new HTML::Template(  filename=>$file, 
                                        vanguard_compatibility_mode=>1,
                                        associate=>[$session, $cgi] );
    $template->param( %{$params} );
    return $template->output();    
}









sub boilerplate {
    my ($self, $content) = @_;

    my %params = (
        CONTENT     => $content,
    );  

    return $self->load_tmpl('Boiler.html', \%params);
}





sub html {
    my $self = shift;

    my $cgi = $self->query();
    my $f = $cgi->param('f') || 'Default.html';

    my $content = $self->load_tmpl($f);
    return $self->boilerplate($content);
}













1;
