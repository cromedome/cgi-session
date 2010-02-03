# $Id$

use strict;
use diagnostics;

use Test::More tests => 6;

# Some driver independent tests for is_params_modified() and reset_modified().

use CGI::Session;

my($loaded_id);
my($modified);
my($new_id);
my($status);

{
	my $s     = CGI::Session -> new;
	$new_id   = $s -> id;
	$status   = $s -> _report_status;
	$modified = $s -> is_params_modified;

	diag "After new: $status. Modified: $modified.";

	$s -> param(key => 'value');

	$status   = $s -> _report_status;
	$modified = $s -> is_params_modified;

	diag "After param: $status. Modified: $modified";
	is($s -> param('key'), 'value', "'value' set and recovered ok");
	diag '-' x 20;
}

{
	my $s      = CGI::Session -> load($new_id);
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');

	$status   = $s -> _report_status;
	$modified = $s -> is_params_modified;

	diag "After new: $status. Modified: $modified.";

	is($s -> param('key'), 'value', "'value' recovered ok");

	diag '-' x 20;
}

{
	my $s      = CGI::Session -> load($new_id);
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');

	$status   = $s -> _report_status;
	$modified = $s -> is_params_modified;

	diag "After load: $status. Modified: $modified.";

	# 1: Call param to change key/value and add new key.
	# 2: Call is_params_modified().
	# 3: Call reset_modified

	$s -> param(key => 'new value');
	$s -> param(other_key => 'other value');

	$modified = $s -> is_params_modified;
	$status   = $s -> _report_status;

	diag "After param: $status. Modified: $modified.";

	# Reset the modification flag. This means in this block the session will not be saved.
	# So in the next block the value recovered will be 'value' and not 'new value'.

	$s -> reset_modified;

	$modified = $s -> is_params_modified;
	$status   = $s -> _report_status;

	diag "After reset_modified: $status. Modified: $modified.";

	diag '-' x 20;
}

{
	my $s      = CGI::Session -> load($new_id);
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');

	$status   = $s -> _report_status;
	$modified = $s -> is_params_modified;

	diag "After new: $status. Modified: $modified.";

	# This should recover 'value' and not 'new value'.

	is($s -> param('key'), 'value', "'value' and not 'new value' recovered ok");

	diag '-' x 20;
}

