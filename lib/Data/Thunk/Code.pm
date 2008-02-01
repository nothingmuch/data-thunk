#!/usr/bin/perl


package Data::Thunk::Code;

use strict;
use warnings;

use Data::Swap ();
use UNIVERSAL::ref;
use Scalar::Util ();

BEGIN {
	our $vivify_code = sub {
		bless $_[0], "Data::Thunk::NoOverload";

		my $code = $_[0]->{code};
		my $tmp = $_[0]->$code();

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

__PACKAGE__

__END__
