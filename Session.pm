package CGI::Session;

# $Id$

use strict;
use Carp 'confess';
use AutoLoader 'AUTOLOAD';

use vars qw($VERSION $errstr $IP_MATCH $COOKIE);

($VERSION)  = '$Revision$' =~ m/Revision:\s*(\S+)/;
$COOKIE     = 'CGISESSID';

# import() - we do not import anything into the callers
# namespace, however, we enable the user to specify
# hooks at compile time
sub import {
    my $class = shift;
    @_ or return;
    for ( my $i=0; $i < @_; $i++ ) {
        $IP_MATCH = ( $_[$i] eq '-ip_match' ) and next;
    }
}


# Session _status flags
sub SYNCED   () { 0 }
sub MODIFIED () { 1 }
sub DELETED  () { 2 }


# new() - constructor.
# Returns respective driver object
sub new {
    my $class = shift;
    $class = ref($class) || $class;

    my $self = {
        _options    => [ @_ ],
        _data       => undef,
        _status     => MODIFIED,
    };

    bless ($self, $class);
    $self->_validate_driver() && $self->_init() or return;
    return $self;
}




# DESTROY() - destructor.
# Flushes the memory, and calls driver's teardown()
sub DESTROY {
    my $self = shift;

    $self->flush();
    $self->can('teardown') && $self->teardown();
}



# _validate_driver() - checks driver's validity.
# Return value doesn't matter. If the driver doesn't seem
# to be valid, it croaks
sub _validate_driver {
    my $self = shift;

    my @required = qw(store retrieve remove generate_id);

    for my $method ( @required ) {
        unless ( $self->can($method) ) {
            my $class = ref($self);
            confess "$class doesn't seem to be a valid CGI::Session driver. " .
                "At least one method('$method') is missing";
        }
    }
    return 1;
}




# _init() - object initialializer.
# Decides between _init_old_session() and _init_new_session()
sub _init {
    my $self = shift;

    my $claimed_id = undef;
    my $arg = $self->{_options}->[0];
    if ( defined ($arg) && ref($arg) ) {
        if ( $arg->isa('CGI') ) {
            $claimed_id = $arg->cookie($COOKIE) || $arg->param($COOKIE) || undef;
        } elsif ( ref($arg) eq 'CODE' ) {
            $claimed_id = $arg->() || undef;

        }
    } else {
        $claimed_id = $arg;
    }

    if ( defined $claimed_id ) {
        my $rv = $self->_init_old_session($claimed_id);

        unless ( $rv ) {
            return $self->_init_new_session();
        }
        return 1;
    }
    return $self->_init_new_session();
}




# _init_old_session() - tries to retieve the old session.
# If suceeds, checks if the session is expirable. If so, deletes it
# and returns undef so that _init() creates a new session.
# Otherwise, checks if there're any parameters to be expired, and
# calls clear() if any. Aftewards, updates atime of the session, and
# returns true
sub _init_old_session {
    my ($self, $claimed_id) = @_;

    my $options = $self->{_options} || [];
    my $data = $self->retrieve($claimed_id, $options);

    # Session was initialized successfully
    if ( defined $data ) {

        $self->{_data} = $data;

        # Check if the IP of the initial session owner should
        # match with the current user's IP
        if ( $IP_MATCH ) {
            unless ( $self->_ip_matches() ) {
                $self->delete();
                $self->flush();
                return undef;
            }
        }

        # Check if the session's expiration ticker is up
        if ( $self->_is_expired() ) {
            $self->delete();
            $self->flush();
            return undef;
        }

        # Expring single parameters, if any
        $self->_expire_params();

        # Updating last access time for the session
        $self->{_data}->{_session_atime} = time();

        # Marking the session as modified
        $self->{_status} = MODIFIED;

        return 1;
    }
    return undef;
}





sub _ip_matches {
    return ( $_[0]->{_data}->{_session_remote_addr} eq $ENV{REMOTE_ADDR} );
}





# _is_expired() - returns true if the session is to be expired.
# Called from _init_old_session() method.
sub _is_expired {
    my $self = shift;

    unless ( $self->expire() ) {
        return undef;
    }

    return ( time() >= ($self->expire() + $self->atime() ) );
}





# _expire_params() - expires individual params. Called from within
# _init_old_session() method on a sucessfully retrieved session
sub _expire_params {
    my $self = shift;

    # Expiring
    my $exp_list = $self->{_data}->{_session_expire_list} || {};
    my @trash_can = ();
    while ( my ($param, $etime) = each %{$exp_list} ) {
        if ( time() >= ($self->atime() + $etime) ) {
            push @trash_can, $param;
        }
    }

    if ( @trash_can ) {
        $self->clear(\@trash_can);
    }
}





# _init_new_session() - initializes a new session
sub _init_new_session {
    my $self = shift;

    $self->{_data} = {
        _session_id => $self->generate_id(),
        _session_ctime => time(),
        _session_atime => time(),
        _session_etime => undef,
        _session_remote_addr => $ENV{REMOTE_ADDR} || undef,
        _session_expire_list => { },
    };

    $self->{_status} = MODIFIED;

    return 1;
}




# id() - accessor method. Returns effective id
# for the current session. CGI::Session deals with
# two kinds of ids; effective and claimed. Claimed id
# is the one passed to the constructor - new() as the first
# argument. It doesn't mean that id() method returns that
# particular id, since that ID might be either expired,
# or even invalid, or just data associated with that id
# might not be available for some reason. In this case,
# claimed id and effective id are not the same.
sub id {
    my $self = shift;

    return $self->{_data}->{_session_id};
}



# param() - accessor method. Reads and writes
# session parameters ( $self->{_data} ). Decides
# between _get_param() and _set_param() accordingly.
sub param {
    my $self = shift;


    unless ( defined $_[0] ) {
        return keys %{ $self->{_data} };
    }

    if ( @_ == 1 ) {
        return $self->_get_param(@_);
    }

    # If it has more than one arguments, let's try to figure out
    # what the caller is trying to do, since our tricks are endless ;-)
    my $arg = {
        -name   => undef,
        -value  => undef,
        @_,
    };

    if ( defined($arg->{'-name'}) && defined($arg->{'-value'}) ) {
        return $self->_set_param($arg->{'-name'}, $arg->{'-value'});

    }

    if ( defined $arg->{'-name'} ) {
        return $self->_get_param( $arg->{'-name'} );
    }

    if ( @_ == 2 ) {
        return $self->_set_param(@_);
    }

    unless ( @_ % 2 ) {
        my $n = 0;
        my %args = @_;
        while ( my ($key, $value) = each %args ) {
            $self->_set_param($key, $value) && ++$n;
        }
        return $n;
    }

    confess "param(): something smells fishy here. RTFM!";
}



# _set_param() - sets session parameter to the '_data' table
sub _set_param {
    my ($self, $key, $value) = @_;

    if ( $self->{_status} == DELETED ) {
        return;
    }

    # session parameters starting with '_session_' are
    # private to the class
    if ( $key =~ m/^_session_/ ) {
        return undef;
    }

    $self->{_data}->{$key} = $value;
    $self->{_status} = MODIFIED;

    return $value;
}




# _get_param() - gets a single parameter from the
# '_data' table
sub _get_param {
    my ($self, $key) = @_;

    if ( $self->{_status} == DELETED ) {
        return;
    }

    return $self->{_data}->{$key};
}


# flush() - flushes the memory into the disk if necessary.
# Usually called from within DESTROY() or close()
sub flush {
    my $self = shift;

    my $status = $self->{_status};

    if ( $status == MODIFIED ) {
        $self->store($self->id, $self->{_options}, $self->{_data});
        $self->{_status} = SYNCED;
    }

    if ( $status == DELETED ) {
        return $self->remove($self->id, $self->{_options});
    }

    $self->{_status} = SYNCED;

    return 1;
}






# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__;

=pod

=head1 NAME

CGI-Session - persistent storage of complex data in CGI applications

=head1 SYNOPSIS

    $sess = new CGI::Session::File(undef, {Directory=>"/tmp"} );
    # or
    $sess = new CGI::Session::DB_File($sid, {Directory=>"/tmp"});
    
    # storing user's login name in the session
    $sess->param("login", $login_name);

    # storing selected parameters from the CGI object
    $sess->save_param($cgi, ["keyword", "category", "limit"]);

    # greeting the user with previously stored login name
    print "Hello, ", $sess->param("login");

    # clearing the login name from the session object for good
    $sess->clear(["login"]);

    # clearing all the params from the login name for good
    $sess->clear();

    # deleting the session itself from both the  disk and the
    # object
    $sess->delete();

=head1 DESCRIPTION

CGI-Session is a Perl5 class that provides an easy, reliable, modular 
and of course persistent session management system across HTTP requests. 
Persistency is a key feature for such applications as shopping carts, 
login/authentication routines, applications that need to collect 
web-site usage statistics and traffic tracking systems. CGI-Session 
provides with just that.

=head1 STATE MAINTANANCE OVERVIEW

Since HTTP is a stateless protocol, each subsequent click to a web site 
is treated as brand new by the web server, and the server does not 
relate them with previous visits. Thus all the state information from the 
previous requests are lost. This makes creating such applications as 
shopping carts, login/authentication routines, secure restricted 
services in the web near impossible. So people had to do something against 
this despair situation HTTP was putting them in.

For our rescue come such technologies as HTTP Cookies and QUERY_STRINGs 
that help us save the users' session for a certain period. Since cookies 
and query_strings alone cannot take us too far [RFC 2965, Section 5, "Implementation Limitations"], 
several other  libraries/technologies have been developed to extend their capabilities 
and promise a more reliable and a more persistent system. CGI::Session is one of them.

=head2 COOOKIE

Cookie is a piece of text-information that a web server is entitled to 
place in the user's hard disk, assuming a user agent (i.e.. Web Browser) 
is compatible with the specification. After the cookie being placed, 
user agents are required to send these cookies back to the server as 
part of the HTTP request. This way the server application ( CGI ) will 
have a way of relating previous requests by the same user agent, thus 
overcoming statelessness of HTTP.

Although cookies seem to be promising solution, they do carry certain limitations, 
such as limited number of cookies per domain and per user agent and limited size 
on each cookie. User Agents are required to store at least 300 cookies at a time, 20 
cookies per domain and allow 4096 bytes of storage for each cookie. They 
also arise several Privacy and Security concerns, the lists of which can 
be found on the sections 6-"Privacy"  and 7-"Security Considerations" of 
RFC 2965 respectively.

=head2 QUERY_STRING

QUERY_STRING is a string appended to URL following a question mark (?) 
such as:

    http://my.dot.com/login.cgi?user=sherzodr;password=topSecret

As you probably guessed already, it can also help you to pass state 
information from a click to another, but how secure is it do you think? 
Considering these URLs tend to get cached by most of the user agents and 
also logged in the servers access log, to which everyone in the machine can 
have access to, it is not secure.

=head2 HIDDEN FIELDS

Hidden field is another alternative to using QUERY_STRINGs and they come 
in two flavors: hidden fields used in POST methods and the ones in GET 
methods. The ones used in GET methods will turn into a true QUERY_STRING 
once submitted, so all the disadvantages of QUERY_STRINGs do apply. 
Although POST requests do not have limitations of its sister-GET, they 
become unwieldily when one has oodles of state information to keep track 
of ( for instance, a shopping cart ). Hidden fields also get lost once 
the user agent closes the session or when the user chooses to click on 
the "Back" button of the browser. Considering the information being sent 
back and forth between the server and the user, the probability of bad 
guys intercepting the request is higher.

=head2 SERVER SIDE SESSION MANAGEMENT

This technique is built upon the aforementioned technologies plus a 
server-side storage, which saves the state data for a particular 
session. Each session has a unique id associated with the data in the 
server. This id is also associated with the user agent in either the 
form of a cookie, a query_string parameter, a hidden field or all at the 
same time. Consider the following story board:

=over  4

=item 1

Mr A requests a page from a program in Server X

=item 2

Program running in Server X generates a unique id "ID-1234", and sends 
the id as a cookie to Mr A's browser. After sending the id, program also 
generates a file or an entry in the database with the name "ID-1234" to 
store all the necessary information such as user preferences, 
logged-in/not flags,  username/email or the list of the products Mr. A 
added to his "shopping cart", etc.

=item 3

When Mr A requests from that program again by clicking on a link, Mr A's 
browser sends the session id back to the program from the cookie file. 
The program running in Server X matches the cookie with the file 
associated file in the server, gets the name of the user previously 
stored ( if it was stored of course ) and says "Hello Mr A. I know it's 
you, confess!".

=back

Advantages:

=over 4

=item *

We no longer need to depend on the User Agent constraints in cookie 
amounts and sizes

=item *

Sensitive data like user's username, email address, preferences and such 
no longer need to be traveling across the network at each request ( 
which is the case with QUERY_STRINGs, cookies and hidden_fields ). Only 
thing that travels across the network is the unique id generated for the 
session ("ID-1234"), which should make no sense to bad guys whatsoever.

=item *

User will not have sensitive data stored in his computer in an unsecured 
plain text format ( which is a cookie file ).

=back

That's what CGI::Session is all about.

=head1 PROGRAMMING STYLE

Server side session management system might be seeming awfully 
convoluted if you have never dealt with it.  Fortunately, with 
CGI::Session this cumbersome task can be achieved in much elegent way 
and handled by the library transparently. This section of the manual can 
be treated as a introductory tutorial to  both logic behind session 
management, and to CGI::Session programming style as well. 

You need to note that you interact with CGI::Session via drivers alone, 
and  as of this distribution the library comes with drivers for File, 
DB_File and MySQL storage devices. For example, to use MySQL driver you 
do:

    use CGI::Session::MySQL;
    my $session = new CGI::Session::MySQL(undef, {Handle=>$dbh});

Only the second argument passed to the driver differs depending on the 
driver you're using. The rest of the code, method calls and the logic 
remain absolutely unaltered. We'll be using File driver to ensure the 
examples will be accessible to any user with the least requirements.

=head2 CREATING A SESSION

When a new user visits our site, we should:

=over 4

=item 1

Create a new id for the user

=item 2

Associate a storage device in the server with the newly generated id

=item 3

Send the ID to the user's computer either as a cookie or as a 
query_string parameters

=back

To generate a brand new id for the user, just pass an undefined value as 
the first argument to CGI::Session driver. For the list of all the 
arguments refer to the driver manual. With the File driver it looks 
like:

    $session = new CGI::Session::File(undef, {Directory=>"/tmp"});

Directory refers to a place where the session files and their locks will 
be stored in the form of separate files. When you generate the session 
object, as we did above, you will have:

=over 4

=item 1

Session ID generated for you and

=item 2

Storage file associated with that file in the directory you specified.

=back

From now on, in case you want to access the newly generated session id 
just do:

    $sid = $session->id();

It returns a string something similar to 
B<bcd22cb2111125fdffaad97d809647e5> which you can now send as a cookie. 
Using CGI.pm of Lincoln Stein you can achieve it with the following 
syntax:

    $sid_cookie = $cgi->cookie(-name=>"CGISESSID", -value=>$sid, 
-expires=>"+30m");
    print $cgi->header( -cookie=>$sid_cookie );

If you're not familiar with CGI.pm usage, please come back here after 
reading the library's manual (L<CGI>).

=head2 INITIALIZING EXISTING SESSIONS

When a user clicks another link or re-visits the site after a short 
while should we be creating a new session again? Absolutely not. This 
would defeat the whole purpose of state maintenance. Since we already 
send the id as a cookie, all we need is to pass that id as the first 
argument while creating a session object:

    $sid_cookie = $cgi->cookie("CGISESSID") || undef;
    $session    = new CGI::Session::File($sid_cookie, 
{Directory=>"/tmp"});

The above syntax will first try to initialize an existing session data, 
if it fails ( if the session doesn't exist ) creates a new session: 
exactly what we want.

You can also achieve the functionality of the above two lines with the 
following syntax. This is new in CGI::Session 3.x:

    $session = new CGI::Session::File($cgi, {Directory=>"/tmp"});

This will try to get the session id either from the cookie or from the 
query_string parameter. If it succeeds, initializes the old session from 
the disk or creates a new session. Name of the cookie and query_string 
parameter the library looks for is B<CGISESSID>. If you'd rather assign 
a different name update the value of B<$CGI::Session::COOKIE> variable 
before creating the object:

    $CGI::Session::COOKIENAME = "SID";
    $session = new CGI::Session::File($cgi, {Directory=>"/tmp"});

=head2 STORING DATA IN THE SESSION

To store a single variable in the object use C<param()> method:

    $session->param("my_name", $name);

You can use C<param()> method to store complex data such as arrays, 
hashes, objects and so forth. While storing arrays and or hashes, make 
sure to pass them as a reference:

    @my_array = ("apple", "grapes", "melon", "casaba");
    $session->param("fruits", \@my_array);

You can store objects as well.

    $session->param("cgi", $cgi);   # stores CGI.pm object

Sometimes you wish there was a way of storing all the CGI parameters in 
the session object. You would start dreaming of this feature after 
having to save dozens of query parameters from each form to your session 
object. Consider the following syntax:

    $session->save_param($cgi, ["keyword", "category", "author", "orderby"]);

The above syntax make sure that all the above CGI parameters get saved 
in the session object. It's the same as saying

    $session->param("keyword",  $cgi->param("keyword"));
    $session->param("category", $cgi->param("category"));
    # etc...

In case you want to save all the CGI parameters. Just omit the second 
argument to C<save_param()>:

    $session->save_param($cgi);

The above saves all the available/accessible CGI parameters

=head2 ACCESSING STORED DATA

There's no point of storing data if you cannot access it. You can access 
stored session data by using the same C<param()> method you once used to 
store them:

    $name = $session->param("my_name");

The above syntax retrieves session parameter previously stored as 
"my_name". To retrieve previously stored @my_array:

    $my_array = $session->param("fruits");

It will return a reference to the array, and can be de referenced as 
@{$my_array}.

Frequently, especially when you find yourself creating drop down menus, 
scrolling lists and checkboxes, you tend to use CGI.pm for its sticky 
behavior that pre-selects default values. To have it preselect the 
values, those selections must be present in the CGI object. 
C<load_param()> method does just that:

    $session->load_param($cgi, ["gender", "q", "subscriptions"]);

It's the same as saying:

    $cgi->param('gender',        $session->param('gender'));
    $cgi->param('q',             $session->param('q') );
    $cgi->param('subscriptions', $session->param('subscriptions'));

but a lot more cleaner?! The above code loads mentioned parameters to the CGI 
object so that they also become available via

    @selected = $cgi->param("checkboxes");

syntax. This triggers sticky behavior of CGI.pm if checkbox 
and scrolling lists are being generated using CGI.pm. If you'd rather 
load all the session parameters to CGI.pm just omit the second parameter 
to C<load_param()>:

    $session->load_param($cgi);

This is the same as doing:

    my @all_params = $session->param();
    for my $param ( @all_params ) {
        $cgi->param($param, $session->param($param));
    }   

This makes sure that all the available and accessible session parameters 
will also be available via CGI object.

If you're making use of HTML::Template to separate the code from the 
skins, you can as well associate CGI::Session object with HTML::Template 
and access all the parameters from within HTML files. We love this 
trick!

    $template = new HTML::Template(filename=>"some.tmpl", associate=>$session );
    print $template->output();

Assuming the session object stored "first_name" and "email" parameters 
while being associated with HTML::Template, you can access those values 
from within your "some.tmpl" file:

    Hello <a href="mailto:<TMPL_VAR email>"> <TMPL_VAR first_name> </a>!

For more tricks with HTML::Template, please refer to the library's 
manual (L<HTML::Template>) and CGI Session Cook Book that comes with the 
library distribution.

=head2 CLOSING THE SESSION

Normally you don't have to close the session explicitly. It gets closed 
when your program terminates or session object goes out of scope. 
However in some few instances you might want to close the session 
explicitly by calling CGI::Session's C<close()> method. What is closing 
all about - you'd ask. While session is active, updates to session 
object doesn't get stored in the disk right away. It stores them in the 
memory until you either choose to flush the buffer by calling C<flush()> 
method or destroy the session object by either terminating the program 
or calling close() method explicitly.

In some circumstances you might want to close the session but at the 
same time don't want to terminate the process for a while. Might be the 
case in GUI and in services. In this case close() is what you 
want.

If you want to keep the session object but for any reason want to 
synchronize the data in the buffer with the one in the disk, C<flush()> 
method is what you need.

Note: undefining an object produces the same effect as close does, 
but is more efficient than calling close()

=head2 CLEARING SESSION DATA

You store data in the session, you access the data in the session and at 
some point you will want to clear certain data from the session, if not 
all. For this reason CGI::Session provides C<clear()> method which 
optionally takes one argument as an arrayref indicating which session 
parameters should be deleted from the session object:

    $session->clear(["~logged-in", "email"]);

Above line deletes "~logged-in" and "email" session parameters from the 
session. And next time you say

    $email = $session->param("email");

it returns undef. If you omit the argument to C<clear()>, be warned that 
all the session parameters you ever stored in the session object will 
get deleted. Note that it does not delete the session itself, for 
session stays open and accessible. It's just the parameters you stored 
in it gets deleted

=head2 DELETING A SESSION

If there's a start there's an end. If session could be created, it 
should be possible to delete it from the disk for good:

    $session->delete();

The above call to C<delete()> deletes the session from the disk for 
good. Do not confuse it with C<clear()>, which only clears certain 
session parameters but keeps the session open.

=head2 DELETE OR CLEAR?

This is a question of beliefs and style. After playing around with 
sessions for a while you'll figure out what you want. If you insist on 
our standing on this rather a controversial issue, don't hesitate to 
drop us an email.

=head1 VARIABLES

CGI::Session makes use of the following configurable variables which you 
can optionally set values to before creating a session object:

=over 4

=item B<$CGI::Session::COOKIE>

Denotes a name of the cookie that holds the session ID of the user. This 
variable is used only if you pass CGI object as the first argument to 
new(). Defaults to "CGISESSID".

=item B<$CGI::Session::IP_MATCH>

Should the library should try to match IP address of the user while 
retrieving an old session. Defaults to "0", which denotes "no"

=item B<$CGI::Session::errstr>

This read-only variable holds the last error message.

=back


=head1 METHODS

Following is the overview of all the available methods accessible via 
CGI::Session object.

=over 4

=item C<new( undef, $hashref )>

=item C<new( $sid, $hashref )>

=item C<new( $cgi, $hashref )>

Object constructor. Requires two arguments: first is either claimed 
session id, or a CGI.pm object. If the first argument is undef, library 
will be forced to create a new session id. Second argument is a 
references to a hash variable, and is driver dependant. For information 
on the contents of the second argument refer to respective driver 
manual. Returns driver object on success, undef on failure. Consult 
$CGI::Session::errstr for an error message

Examples:

    $session = new CGI::Session::File(undef,    { Directory=>"/tmp" });
    $session = new CGI::Session::MySQL($cgi,    { Handle=>$dbh } );
    $session = new CGI::Session::DB_File($sid,  { Directory=>"/tmp" });

=item C<id()>

Returns effective ID for a session. Since effective ID and claimed ID 
can differ, valid session id should always be retrieved using this 
method. Return value: string denoting the session id.

=item C<param($name)>

=item C<param(-name=E<gt>$name)>

this method used in either of the above syntax returns a session 
parameter set to C<$name> or undef on failure.

=item C<param( $name, $value)>

=item C<param(-name=E<gt>$name, -value=E<gt>$value)>

method used in either of the above syntax assigns a new value to $name 
parameter, which can later be retrieved with previously introduced 
param() syntax.

=item C<param_hashref()>

returns all the session parameters as a reference to a hash


=item C<save_param($cgi)>

=item C<save_param($cgi, [@list])>

Saves CGI parameters to session object. In otherwords, it's calling 
C<param($name, $value)> for every single CGI parameter. The first 
argument should be either CGI object or any object which can provide an 
alternative to a param() method. If second argument is present and is a 
reference to an array, only those CGI parameters found in the array will 
be stored in the session

=item C<load_param($cgi)>

=item C<load_param($cgi, [@list])>

loads session parameters to CGI object. The first argument is required 
to be either CGI.pm object, or any other object which can provide 
param() method. If second argument is present and is a reference to an 
array, only the parameters found in that array will be loaded to CGI 
object.

=item C<clear()>

=item C<clear([@list])>

clears parameters from the session object. If passed an argument as an 
arrayref, clears only those parameters found in the list.

=item C<flush()>

synchronizes data in the buffer with its copy in disk. Normally it will 
be called for you just before the program terminates, session object 
goes out of scope or close() is called.

=item C<close()>

closes the session temporarily until new() is called on the same session 
next time. In other words, it's a call to flush() and DESTROY()

=item C<atime()>

returns the last access time of the session in the form of seconds from 
epoch. Is used while expiring sessions.

=item C<ctime()>

returns the time of the session data in the form of seconds from epoch, 
denoting the date when session was created for the first time.

=item C<expires()>

=item C<expires($time)>

=item C<expires($param, $time)>

Sets expiration date relative to atime(). If used with no arguments, 
returns the expiration date if it was ever set for a whole object. If
the session is non-expiring, returns undef.

Second form sets an expiration date for a whole session. This value is 
checked when previously stored session is asked to be retrieved, and if 
its expiration date has passed will be expunged from the disk 
immediately and new session is created accordingly. Passing -1 would 
cancel expiration date

By using the third syntax you can also set an expiration date for a 
particular session parameter, say "~logged-in". This would cause the 
library call clear() on the parameter when its time is up.

All the time values should be given in the form of seconds. Following 
time aliases are also supported for your convenience:

    +===========+===============+
    |   alias   |   meaning     |
    +===========+===============+
    |     s     |   Second      |
    |     m     |   Minute      |
    |     h     |   Hour        |
    |     w     |   Week        |
    |     M     |   Month       |
    |     y     |   Year        |
    +-----------+---------------+

Examples:

    $session->expires("+1y");   # expires in one year
    $session->expires(0);       # cancel expiration
    $session->expires("~logged-in", "+10m");
                    # expires ~logged-in flag in 10 mins

Note: all the expiration times are relative to session's last access 
time, not to its creation time. To expire a session immediately, call 
delete().

=item C<remote_addr()>

Returns the remote address of the user who created the session for the 
first time. Returns undef if variable REMOTE_ADDR wasn't present in the 
environment when the session was created

=item C<delete()>

deletes the session from the disk. In other words, it calls for 
immediate expiration after which the session will not be accessible

=item C<error()>

returns the last error message from the library. It's the same as the 
value of $CGI::Session::errstr. Example:

    $session->flush() or die $session->error();

=item C<dump()>

=item C<dump("logs/dump.txt")>

creates a dump of the session object. Argument, if passed, will be 
interpreted as the name of the file object should be dumped in. Used 
mostly for debugging.

=item C<trace("logs/trace.txt")>

creates a trace log file of the method calls. Used for debugging only. 
To turn off tracing pass undef as an argument.

=item C<traverse()>

walks through the list of all the session data available in the disk. 
This method is driver dependant, so consult with driver's manual first. 
Returns object for next session in the disk. Suitable for while() loops

Example:

    use constant YEAR => 3600 * 24 * 365;

    while ( my $tmp_sess = $session->traverse ) {
        # expire if it wasn't accessed for the last one year
        if ( $tmp_sess->atime() > YEAR ) {
            $tmp_sess->delete() and next;
        }

        my $etime = $tmp_sess->expires() or next;
        my $atime = $tmp_sess->atime();

        if ( ($atime+$etime) <= time() ) {
            $tmp_sess->delete();
        }
    }

This example might be suitable to be part of your program logic if your 
site is not way to crowded. Otherwise consider setting up a cron tab.

=back

=head1 SECURITY

How secure is using CGI::Session? Can others hack down people's sessions 
using another browser if they can get the session id of the user? Are 
the session ids guessable? - are the questions I find myself answering 
over and over again.

=head2 STORAGE

Security of the library does in many aspects depend on the 
implementation of the library. After making use of this library, you 
longer have to send all the information to the user's cookie except for 
the session id. But, you still have to store the data in the server 
side. So another set of questions arise, can an evil person have access 
to session data in your server, even if they do, can they make sense of 
the data in the session file, and even if they can, can they reuse the 
information against a person who created that session. As you see, the 
answer depends on yourself who is implementing it.

First rule of thumb, please do not save the users password or his credit 
card number in the session. If you can persuade your conscious that this 
is necessary, make sure that evil eyes don't have access to session 
files in your server. If you're using RDBMS driver such as MySQL, the 
database will be protected with a username/password pair. But if it will 
be storing in the file system in the form of plain files, make sure no 
one except you can have access to those files.

Default configuration of the driver makes use of Data::Dumper class to 
serialize data to make it possible to save it in the disk. 
Data::Dumper's result is a human readable data structure, which if 
opened, can be interpreted by an evil creature against you. If you 
configure your CGI::Session implementation to use either Storable or 
FreezeThaw as a serializer, this would make more difficult for bad guys 
to interpolate the data. But don't use this as the only precaution for 
security. Since evil fingers can type a quick program using Storable or 
FreezeThaw which deciphers that session file very easily.

Also, do not allow evil and sick minds to update the contents of session 
files. Of course CGI::Session makes sure it doesn't happen, but your 
cautiousness does no harm either.

=head2 SESSION IDs

Session ids are not easily guessable. Default configuration of 
CGI::Session uses Digest::MD5 which takes process id, time in seconds 
since epoch and a random number and generates a 32 character long 
string. Although this string cannot be guessable by others, if they find 
it out somehow, can they use this identifier against the other person?

Consider the case, where you just give someone either via email or an 
instant messaging a link to your online-account profile, where you're 
currently logged in. The URL you give to that person contains a session 
id as part of a query_string. If your application was initializing the 
id solely using query_string parameter, after clicking on that link that 
person now appears to that site as you, and might have access to all of 
your private data instantly. How scary and how unwise implementation and 
what a poor kid who didn't know that pasting URLs with session ids is 
not a good idea.

Even if you're solely using cookies as the session id transporters, it's 
not that difficult to plant a cookie in the cookie file with the same id 
and trick the application  this way. So key for security is to check if 
the person who's asking us to retrieve a session data is indeed the 
person who initially created the session data. CGI::Session helps you to 
watch out for such cases by setting a special variable, 
$CGI::Session::IP_MATCH to a true value, say to 1. This makes sure that 
before initializing a previously stored session, it checks if the ip 
address stored in the session matches the ip address of the user asking 
for that session. In which case the library returns the session, 
otherwise it dies with a proper error message. You can also set 
$CGI::Session::HOST_MATCH instead, or both at the same time. These 
variable updates should take place before creating the session object:

    require CGI::Session::File;

    $CGI::Session::IP_MATCH     = 1;    # default is 0    
    $session = new CGI::Session::File($cgi, {Directory=>"/tmp"});

=head1 DRIVER SPECIFICATIONS

This section is for driver authors who want to implement their own 
storing mechanism for the library. Those who enjoy sub-classing stuff 
should find this section useful as well. Here we discuss the 
architecture of the library.

=head2 LIBRARY OVERVIEW

Library provides all the base methods listed in the L</METHODS> section. 
The only methods CGI::Session doesn't bother providing are the ones that 
need to deal with writing the session data in the disk, retrieving the 
data from the disk, and deleting the data. These are the methods 
specific to the driver, so that's where they should be provided.

In other words, driver is just another Perl library which uses 
CGI::Session as a base class, and provides several additional methods 
that deal with disk-access and storage

=head2 SERIALIZATION

Before getting to driver specs, let's talk about how the data should be 
stored. When flush() is called, or the program terminates, CGI::Session 
asks a driver to store the data somewhere in the disk, and passes the 
data in the form of a hash reference. Then it's the driver's obligation 
to serialize the data so that it can be stored in the disk.

CGI::Session distribution comes with several libraries you can inherit 
from and call freeze() method on the object to serialize the data and 
store it. Those libraries are:

=over 4

=item B<CGI::Session::Serialize::Default>

=item B<CGI::Session::Serialize::Storable>

=item B<CGI::Session::Serialize::FreezeThaw>

=back

Refer to their respective manuals for more details

Example:

    # $data is a hashref that needs to be stored
    my $storable_data = $self->freeze($data)

$storable_data can now be saved in the disk

When the driver is asked to retrieve the data from the disk, that 
serialized data should be accordingly de-serialized. The aforementioned 
serializer also provide thaw() method, which takes serialized data as 
the first argument, and returns Perl data structure, as it was before 
saved. Example:

    return $self->thaw($stored_data);


=head2 DRIVER METHODS

Driver is just another Perl library, which uses CGI::Session as a base 
class and is required to provide the following methods:

=over 4

=item C<retrieve($self, $sid, $options)>

this methods is called by CGI::Session with the above 3 arguments when 
it's asked to retrieve the session data from the disk. $self is the 
session object, $sid is the session id, and $options is the list of the 
arguments passed to new() in the form of a hashref. Method should return 
un-serialized session data, or undef indicating the failure. If an error 
occurs, instead of calling die() or croak(), we suggest setting the 
error message to error() and returning undef:

    unless ( sysopen(FH, $options->{FileName}, O_RDONLY) ) {
        $self->error("Couldn't read from $options->{FileName}: $!");
        return undef;
    }

=item C<store($self, $sid, $data, $options)>

this method is called by CGI::Session when session data needs to be 
stored. Data to be stored is passed as the third argument to the method, 
and is a reference to a hash. Should return any true value indicating 
success, undef otherwise. Error message should be passed to error().

=item C<remove($self, $sid, $options)>

called when CGI::Session is asked to remove the session data from the 
disk via delete() method. Should return true indicating success, undef 
otherwise, setting the error message to error()

=item C<teardown($self, $sid, $options)>

called when session object is about to get destroyed, either via close() 
or implicitly when the program terminates

=back

=head2 GENERATING ID

CGI::Session also requires the driver to provide a generate_id() method, 
which returns an id for a new session. So CGI::Session distribution 
comes with libraries that provide you with generate_id() and you can 
simply inherit from them. Following libraries are available:

=over 4

=item B<CGI::Session::ID::Default>

=item B<CGI::Session::ID::Incr>

=back

Refer to their respective manuals for more details.

In case you want to have your own style of ids, you can define a 
generate_id() method explicitly without inheriting from the above 
libraries.

=head2 BLUEPRINT

Your CGI::Session distribution comes with a Session/Blueprint.pm file 
which can be used as a starting point for your drive. Or consider the 
following blueprint:

    package CGI::Session::MyDriver;

    # inherit missing methods from the following classes
    use base qw(
        CGI::Session
        CGI::Session::Serialize::Default
        CGI::Session::ID::Default
    );

    use vars qw($VERSION);

    $VERSION = '1.1';

    sub retrieve {
        my ($self, $sid, $options) = @_;


    }
    sub store {
        my ($self, $sid, $data, $options) = @_;
        my $storable_data = $self->freeze($data);

    }
    sub remove {
        my ($self, $sid, $options) = @_;

    }
    sub teardown {
        my ($self, $sid, $options) = @_;

    }
    1;
    __END__;


After filling in the above blanks, you can do:

    $session = new CGI::Session::MyDriver($sid, {Option=>"Value"});

and use the library according to this manual.


=head1 COPYRIGHT

Copyright (C) 2001, 2002 Sherzod Ruzmetov <sherzodr@cpan.org>

This library is free software. You can modify and or distribute it under 
the same terms as Perl itself.

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>.
http://author.ultracgis.com

=head1 SEE ALSO

=over 4

=item CGI::Session Drivers

L<CGI::Session::File>, L<CGI::Session::DB_File>, L<CGI::Session::MySQL>, 
L<CGI::Session::BerkelyDB>

=item CGI Session Cook Book

L<cgisesscook> - Cook Book which is a part of the library distribution

=item CGI.pm

Perl's Simple Common Gateway Interface class by Lincoln Stein

=item Apache::Session

Another fine session library by Jeffrey Baker <jwbaker@acm.org>

=item RFC 2965

"HTTP State Management Mechanism" found at 
ftp://ftp.isi.edu/in-notes/rfc2965.txt

=back

=cut

# dump() - dumps the session object using Data::Dumper
sub dump {
    my ($self, $file) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = 1;

    my $d = new Data::Dumper([$self], ["cgisession"]);

    if ( defined $file ) {
        unless ( open(FH, '<' . $file) ) {
            unless(open(FH, '>' . $file)) {
                $self->error("Couldn't open $file: $!");
                return undef;
            }
            print FH $d->Dump();
            unless ( close(FH) ) {
                $self->error("Couldn't dump into $file: $!");
                return undef;
            }            
        }
    }
    return $d->Dump();
}



sub version {   return $VERSION()   }


# delete() - sets the '_status' session flag to DELETED,
# which flush() uses to decide to call remove() method on driver.
sub delete {
    my $self = shift;

    # If it was already deleted, make a confession!
    if ( $self->{_status} == DELETED ) {
        confess "delete attempt on deleted session";
    }

    $self->{_status} = DELETED;
}





# clear() - clears a list of parameters off the session's '_data' table
sub clear {
    my $self = shift;
    $class   = ref($class);

    my @params = ();
    if ( defined $_[0] ) {
        unless ( ref($_[0]) eq 'ARRAY' ) {
            confess "Usage: $class->clear([\@array])";
        }
        @params = @{ $_[0] };

    } else {
        @params = $self->param();

    }

    my $n = 0;
    for ( @params ) {
        /^_session_/ and next;
        # If this particular parameter has an expiration ticker,
        # remove it.
        if ( $self->{_data}->{_session_expire_list}->{$_} ) {
            delete ( $self->{_data}->{_session_expire_list}->{$_} );
        }
        delete ($self->{_data}->{$_}) && ++$n;
    }

    # Set the session '_status' flag to MODIFIED
    $self->{_status} = MODIFIED;

    return $n;
}


# save_param() - copies a list of third party object parameters
# into CGI::Session object's '_data' table
sub save_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess "save_param(): first argument should be an object";

    }
    unless ( $cgi->can('param') ) {
        confess "save_param(): Cannot call method param() on the object";
    }

    my @params = ();
    if ( defined $list ) {
        unless ( ref($list) eq 'ARRAY' ) {
            confess "save_param(): second argument must be an arrayref";
        }

        @params = @{ $list };

    } else {
        @params = $cgi->param();

    }

    my $n = 0;
    for ( @params ) {
        # It's imporatnt to note that CGI.pm's param() returns array
        # if a parameter has more values associated with it (checkboxes
        # and crolling lists). So we should access its parameters in
        # array context not to miss anything
        my @values = $cgi->param($_);

        if ( defined $values[1] ) {
            $self->_set_param($_ => \@values);

        } else {
            $self->_set_param($_ => $values[0] );

        }

        ++$n;
    }

    return $n;
}


# load_param() - loads a list of third party object parameters
# such as CGI, into CGI::Session's '_data' table
sub load_param {
    my ($self, $cgi, $list) = @_;

    unless ( ref($cgi) ) {
        confess "save_param(): first argument must be an object";

    }
    unless ( $cgi->can('param') ) {
        my $class = ref($cgi);
        confess "save_param(): Cannot call method param() on the object $class";
    }

    my @params = ();
    if ( defined $list ) {
        unless ( ref($list) eq 'ARRAY' ) {
            confess "save_param(): second argument must be an arrayref";
        }
        @params = @{ $list };

    } else {
        @params = $self->param();

    }

    my $n = 0;
    for ( @params ) {
        $cgi->param(-name=>$_, -value=>$self->_get_param($_));
    }
    return $n;
}




# another, but a less efficient alternative to undefining
# the object
sub close {
    my $self = shift;

    $self->DESTROY();
}



# error() returns/sets error message
sub error {
    my ($self, $msg) = @_;

    if ( defined $msg ) {
        $errstr = $msg;
    }

    return $errstr;
}


# errstr() - alias to error()
sub errstr {
    my $self = shift;

    return $self->error(@_);
}



# atime() - rerturns session last access time
sub atime {
    my $self = shift;

    if ( @_ ) {
        confess "_session_atime - read-only value";
    }

    return $self->{_data}->{_session_atime};
}


# ctime() - returns session creation time
sub ctime {
    my $self = shift;

    if ( defined @_ ) {
        confess "_session_atime - read-only value";
    }

    return $self->{_data}->{_session_ctime};
}


# expire() - sets/returns session/parameter expiration ticker
sub expire {
    my $self = shift;

    unless ( @_ ) {
        return $self->{_data}->{_session_etime};
    }

    if ( @_ == 1 ) {
        return $self->{_data}->{_session_etime} = _time_alias( $_[0] );
    }

    # If we came this far, we'll simply assume user is trying
    # to set an expiration date for a single session parameter.
    my ($param, $etime) = @_;

    # Let's check if that particular session parameter exists
    # in the '_data' table. Otherwise, return now!
    defined ($self->{_data}->{$param} ) || return;

    if ( $etime == -1 ) {
        delete $self->{_data}->{_session_expire_list}->{$param};
        return;
    }

    $self->{_data}->{_session_expire_list}->{$param} = _time_alias( $etime );
}



# parses such strings as '+1M', '+3w', accepted by expire()
sub _time_alias {
    my ($str) = @_;

    # If $str consists of just digits, return them as they are
    if ( $str =~ m/^\d+$/ ) {
        return $str;
    }

    my %time_map = (
        s           => 1,
        m           => 60,
        h           => 3600,
        d           => 3600 * 24,
        w           => 3600 * 24 * 7,
        M           => 3600 * 24 * 30,
        y           => 3600 * 24 * 365,
    );

    my ($koef, $d) = $str =~ m/([+-]?\d+)(\w)/;

    if ( defined($koef) && defined($d) ) {
        return $koef * $time_map{$d};
    }
}


# remote_addr() - returns ip address of the session
sub remote_addr {
    my $self = shift;

    return $self->{_data}->{_session_remote_addr};
}


# param_hashref() - returns parameters as a reference to a hash
sub param_hashref {
    my $self = shift;

    return $self->{_data};
}


# $Id$
