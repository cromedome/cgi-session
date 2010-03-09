# cookie.free.t

use diagnostics;
use lib 't';
use strict;

use File::Spec;
use CGI::Session;
use CookieFree;
use Test::More tests => 3;

# We use a separate directory so these test sessions are kept separate.

my($dsn_opt)     = {Directory => File::Spec->tmpdir};
my($session_opt) = {query_class => 'CookieFree'};

my($loaded_id);
my($new_id);

{
    my $s   = CGI::Session->new(undef, undef, $dsn_opt, $session_opt);
    $new_id = $s->id;

    $s->param(key => 'value');

    is($s->param('key'), 'value', "'value' set and recovered ok");

    #diag '-' x 20;
}

{
    my $s      = CGI::Session->load(undef, $new_id, $dsn_opt, $session_opt);
    $loaded_id = $s->id;

    is($new_id, $loaded_id, 'Loaded id matches new id');
    is($s->param('key'), 'value', "'value' recovered ok");

    #diag '-' x 20;
}
