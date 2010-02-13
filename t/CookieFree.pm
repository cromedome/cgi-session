package CookieFree;

use Test::More; # For diag method only.

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return $self;
}

sub param {
    my($self, $key) = @_;
    $key ||= '';
    diag "Called CookieFree.param.";
    return $$self{$key};
}

1;
