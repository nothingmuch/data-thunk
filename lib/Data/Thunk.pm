#!/usr/bin/perl

package Data::Thunk;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use base qw(Exporter);

our $VERSION = "0.01";

our @EXPORT = our @EXPORT_OK = qw(lazy force);

sub lazy (&) {
	my $thunk = shift;
	bless { code => $thunk }, "Data::Thunk::Code";
}

my ( $vivify_code, $vivify_scalar ); # these lexicals go into the other packages' scopes

sub force ($) {
	my $val = shift;

	if ( blessed($val) ) { 
		if ( blessed($val) eq 'Data::Thunk::Code' ) {
			return $val->$vivify_code;
		} elsif ( blessed($val) eq 'Data::Thunk::ScalarValue' ) {
			return $val->$vivify_scalar;
		}
	}

	return $val;
}

{
	package Data::Thunk::NoOverload;
	# we temporarily bless into this to avoid overloading
}

{
	package Data::Thunk::Code;
	use Data::Swap ();
	use UNIVERSAL::ref;

	use overload (
		fallback => 1, map {
			$_ => $vivify_code = sub {
				bless $_[0], "Data::Thunk::NoOverload";

				my $tmp = $_[0]->{code}->();

				if ( CORE::ref($tmp) ) {
					local $@;
					eval { Data::Swap::swap $_[0], $tmp };

					if ( my $e = $@ ) {
						# try to figure out where the thunk was defined
						my $lazy_ctx = eval {
							require B;
							my $cv = B::svref_2object($_[0]->{code});
							my $file = $cv->FILE;
							my $line = $cv->START->line;
							"in thunk defined at $file line $line";
						} || "at <<unknown>>";

						my $file = quotemeta(__FILE__);
						$e =~ s/ at $file line \d+.\n$/ $lazy_ctx, vivified/; # becomes "vivified at foo line blah"..

						require Carp;
						Carp::croak($e);
					}

					return $_[0];
				} else {
					Data::Swap::swap $_[0], do { my $o = $tmp; \$o };
					bless $_[0], "Data::Thunk::ScalarValue";
					return $_[0];
				}
			},
		} qw( bool "" 0+ ${} @{} %{} &{} *{} )
	);

	my $vivify_and_call = sub {
		my $method = shift;
		$_[0]->$vivify_code();
		goto &{$_[0]->can($method)}
	};

	sub ref {
		CORE::ref($_[0]->$vivify_code);
	}

	foreach my $sym (keys %UNIVERSAL::) {
		no strict 'refs';
		*{$sym} = eval "sub {
			if ( Scalar::Util::blessed(\$_[0]) ) {
				unshift \@_, \$sym;
				goto \$vivify_and_call;
			} else {
				shift->SUPER::$sym(\@_);
			}
		}";
	}

	sub AUTOLOAD {
		my ( $self, @args ) = @_;
		my ( $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );
		unshift @_, $method;
		goto $vivify_and_call;
	}

	sub DESTROY {
		# don't create the value just to destroy it
	}
}

{
	package Data::Thunk::ScalarValue;
	use UNIVERSAL::ref;

	use overload (
		fallback => 1, map {
			$_ => $vivify_scalar = sub {
				my $self = $_[0];

				# must rebless to something unoverloaded in order to get at the value
				bless $self, "Data::Thunk::NoOverload";
				my $val = $$self;
				bless $self, __PACKAGE__;

				# try to replace the container with the value wherever we found it
				local $@; eval { $_[0] = $val }; # might be readonly;

				$val;
			}
		} qw( bool "" 0+ ${} @{} %{} &{} *{} )
	);

	sub ref {
		my $self = shift;
		return;
	}

	sub DESTROY { }
}

__PACKAGE__

__END__

=pod

=head1 NAME

Data::Thunk - A sneakier Scalar::Defer ;-)

=head1 SYNOPSIS

	use Data::Thunk qw(lazy);

	my %hash = (
		foo => lazy { $expensive },
	);

	$hash{bar}{gorch} = $hash{foo};

	$hash{bar}{gorch}->foo; # vivifies the object

	warn overload::StrVal($hash{foo}); # replaced with the value

=head1 DESCRIPTION

This is an implementation of thunks a la L<Scalar::Defer>, but uses
L<Data::Swap> and assignment to C<$_[0]> in order to leave a minimal trace of the thunk.

In the case that a reference is returned from C<lazy { }> L<Data::Swap> can
replace the thunk ref with the result ref, so all the references that pointed
to the thunk are now pointing to the result (at the same address).

If a simple value is returned then the thunk is swapped with a simple scalar
container, which will assign the value to C<$_[0]> on each overloaded use.

In this particular example:

	my $x = {
		foo => lazy { "blah" },
		bar => lazy { [ "boink" ] },
	};

	$x->{quxx} = $x->{foo};
	$x->{gorch} = $x->{bar};

	warn $x->{bar};
	warn $x->{foo};
	warn $x->{quxx};

	use Data::Dumper;
	warn Dumper($x);

The resulting structure is:

	$VAR1 = {
		'bar' => [ 'boink' ],
		'foo' => 'blah',
		'gorch' => $VAR1->{'bar'},
		'quxx' => 'blah'
	};

Whereas with L<Scalar::Defer> the trampoline objects remain:

	$VAR1 = {
		'bar' => bless( do{\(my $o = 25206320)}, '0' ),
		'foo' => bless( do{\(my $o = 25387232)}, '0' ),
		'gorch' => $VAR1->{'bar'},
		'quxx' => $VAR1->{'foo'}
	};

This is potentially problematic because L<Scalar::Util/reftype> and
L<Scalar::Util/blessed> can't be fooled. With L<Data::Thunk> the problem still
exists before values are vivified, but not after.

Furthermore this module uses L<UNIVERSAL::ref> instead of blessing to C<0>.
Blessing to C<0> pretends that everything is a non ref (C<ref($thunk)> returns
the name of the package, which evaluates as false), so deferred values that
become objects don't appear to be as such.

=head1 EXPORTS

=over 4

=item lazy { ... }

Create a new thunk.

=item force

Vivify the value and return the result.

=back

=head1 SEE ALSO

L<Scalar::Defer>, L<Data::Lazy>, L<Data::Swap>, L<UNIVERSAL::ref>.

=head1 VERSION CONTROL

This module is maintained using Darcs. You can get the latest version from
L<http://nothingmuch.woobling.org/code>, and use C<darcs send> to commit
changes.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

	Copyright (c) 2008 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut



=cut


