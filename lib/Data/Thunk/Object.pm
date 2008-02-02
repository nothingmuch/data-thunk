#!/usr/bin/perl

package Data::Thunk::Object;
use base qw(Data::Thunk::Code);

use strict;
use warnings;

use UNIVERSAL::ref;
use Scalar::Util ();

our $get_field = sub {
	my ( $obj, $field ) = @_;

	my $thunk_class = Scalar::Util::blessed($obj) or return;
	bless $obj, "Data::Thunk::NoOverload";

	my $exists = exists $obj->{$field};
	my $value = $obj->{$field};

	bless $obj, $thunk_class;

	# ugly, but it works
	return ( wantarray
		? ( $exists, $value )
		: $value );
};

sub ref {
	my ( $self, @args ) = @_;

	if ( my $class = $self->$get_field("class") ) {
		return $class;
	} else {
		return $self->SUPER::ref(@args);
	}
}


foreach my $sym (keys %UNIVERSAL::) {
	no strict 'refs';

	next if $sym eq 'ref::';
	next if defined &$sym;
	*{$sym} = eval "sub {
		my ( \$self, \@args ) = \@_;

		if ( my \$class = \$self->\$get_field('class') ) {
			return \$class->$sym(\@args);
		} else {
			return \$self->SUPER::$sym(\@args);
		}
	}";

	warn $@ if $@;
}

sub AUTOLOAD {
	my ( $self, @args ) = @_;
	my ( $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );

	if ( $method !~ qr/^(?: class | code )$/ ) {
		my ( $exists, $value ) = $self->$get_field($method);

		if ( $exists ) {
			if ( (reftype($value)||'') eq 'CODE' ) {
				return $self->$value(@args);
			} else {
				return $value;
			}
		}
	}

	unshift @_, $method;
	goto $Data::Thunk::Code::vivify_and_call;
}

__PACKAGE__

__END__
