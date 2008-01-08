use Test::More tests => 14;
use ok 'Data::Thunk';

my $y = 0;
my $l = lazy { ++$y };

is($y, 0, "not triggered yet");

is($l, 1, "lazy value");

is($y, 1, "trigerred");

my $forced = force lazy { 4 };
is($forced, 4, 'force($x) works');
is($forced, 4, 'force($x) is stable');
is(force $forced, 4, 'force(force($x)) is stable');

$SomeClass::VERSION = 42;
sub SomeClass::meth { 'meth' };
sub SomeClass::new { bless(\@_, $_[0]) }

is(ref(lazy { SomeClass->new }), 'SomeClass', 'ref() returns true for refs');
ok(!ref(lazy { "foo" }), 'ref() returns false for simple values');
is(ref(force lazy { SomeClass->new }), 'SomeClass', 'ref() returns true for forced values');
is(lazy { SomeClass->new }->meth, 'meth', 'method call works on deferred objects');
is(lazy { SomeClass->new }->can('meth'), SomeClass->can('meth'), '->can works too');
ok(lazy { SomeClass->new }->isa('SomeClass'), '->isa works too');
is(lazy { SomeClass->new }->VERSION, SomeClass->VERSION, '->VERSION works too');
