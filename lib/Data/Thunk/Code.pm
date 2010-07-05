#!/usr/bin/perl


package Data::Thunk::Code;

use strict;
use warnings;

use Try::Tiny;
use Data::Swap;
use Scalar::Util qw(reftype blessed);
use Carp;

use namespace::clean;

use UNIVERSAL::ref;

BEGIN {
	our $vivify_code = sub {
		bless $_[0], "Data::Thunk::NoOverload";

		my $scalar = reftype($_[0]) eq "REF";
		my $code = $scalar ? ${ $_[0] } : $_[0]->{code};
		my $tmp = $_[0]->$code();

		if ( CORE::ref($tmp) ) {
			my $ref = \$_[0]; # try doesn't get $_[0]

			try {
				swap $$ref, $tmp;
			} catch {
				# try to figure out where the thunk was defined
				my $lazy_ctx = try {
					require B;
					my $cv = B::svref_2object($_[0]->{code});
					my $file = $cv->FILE;
					my $line = $cv->START->line;
					"in thunk defined at $file line $line";
				} || "at <<unknown>>";

				my $file = __FILE__;
				s/ at \Q$file\E line \d+.\n$/ $lazy_ctx, vivified/; # becomes "vivified at foo line blah"..

				croak($_);
			};

			return $_[0];
		} else {
			if ( $scalar ) {
				${ $_[0] } = $tmp;
			} else {
				Data::Swap::swap $_[0], do { my $o = $tmp; \$o };
			}
			bless $_[0], "Data::Thunk::ScalarValue";
			return $tmp;
		}
	};
}

our $vivify_code;

use overload ( fallback => 1, map { $_ => $vivify_code } qw( bool "" 0+ ${} @{} %{} &{} *{} ) );

our $vivify_and_call = sub {
	my $method = shift;
	$_[0]->$vivify_code();
	goto &{$_[0]->can($method)}
};

sub ref {
	CORE::ref($_[0]->$vivify_code);
}

foreach my $sym (keys %UNIVERSAL::) {
	no strict 'refs';

	next if $sym eq 'ref::';
	next if defined &$sym;

	local $@;

	eval "sub $sym {
		if ( Scalar::Util::blessed(\$_[0]) ) {
			unshift \@_, '$sym';
			goto \$vivify_and_call;
		} else {
			shift->SUPER::$sym(\@_);
		}
	}; 1" || warn $@;
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

__PACKAGE__

__END__
