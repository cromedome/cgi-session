# $Id$

use strict;
use diagnostics;

use File::Spec;
use Test::More tests => 9;
use Test::Differences;

use CGI::Session;

# We use a separate directory so the tests for the modification times
# of files only test files created in the current run of this script.

my($opt_dsn) = {Directory => File::Spec -> tmpdir};

my(@file_name, %first_time);
my($loaded_id);
my($new_id);
my($status, %second_time);

{
	my $s      = CGI::Session -> new(undef, undef, $opt_dsn);
	$new_id    = $s -> id;
	$status    = $s -> _report_status;

	#diag "After new: $status.";

	$s -> param(key => 'value');

	is($s -> param('key'), 'value', "'value' set and recovered ok");

	$status = $s -> _report_status;

	#diag "After param: $status.";
	#diag '-' x 20;
}

{
	my $s      = CGI::Session -> load(undef, $new_id, $opt_dsn);
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');
	is($s -> param('key'), 'value', "'value' recovered ok");

	$status = $s -> _report_status;

	#diag "After new: $status";
	#diag '-' x 20;
}

# Save the
CGI::Session -> find(sub {push @file_name, '/tmp/cgisess_' . shift -> id});

for (@file_name)
{
	$first_time{$_} = (stat $_)[9];
}

{
	# Reset the auto_flush flag. This means exiting the block the session will not be saved.
	# So in the next block the value recovered will be 'value' and not 'new value'.

	my $s      = CGI::Session -> load(undef, $new_id, $opt_dsn, {auto_flush => 0});
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');

	$status = $s -> _report_status;

	#diag "After load: $status.";

	$s -> param(key => 'new value');
	$s -> param(other_key => 'other value');

	$status = $s -> _report_status;

	#diag "After param: $status";
	#diag '-' x 20;
}

{
	# Reset the update_atime flag. This means exiting the block the session will not be saved.
	# So in the next block, the age of the file (-A) will be the same as just after this load.

	my $s      = CGI::Session -> load(undef, $new_id, $opt_dsn, {update_atime => 0});
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');
	is($s -> param('key'), 'value', "'value' recovered ok");

	$status = $s -> _report_status;

	#diag "After load(undef, \$new_id, {}, {update_atime => 0}): $status.";
	#diag '-' x 20;
}

# Since the last 2 blocks stopped sessions being saved, the last modification time
# of each session file should not have changed.

CGI::Session -> find(sub {push @file_name, '/tmp/cgisess_' . shift -> id});

for (@file_name)
{
	$second_time{$_} = (stat $_)[9];
}

eq_or_diff([map{$first_time{$_} } sort keys %first_time], [map{$second_time{$_} } sort keys %second_time]);

{
	my $s      = CGI::Session -> load(undef, $new_id, $opt_dsn);
	$loaded_id = $s -> id;

	is($new_id, $loaded_id, 'Loaded id matches new id');

	# This should recover 'value' and not 'new value'.

	is($s -> param('key'), 'value', "'value' and not 'new value' recovered ok");

	$status = $s -> _report_status;

	#diag "After new: $status.";
	#diag '-' x 20;
}
