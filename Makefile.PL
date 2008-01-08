#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

use 5.010;

WriteMakefile(
	NAME         => 'Data::Thunk',
	VERSION_FROM => 'lib/Data/Thunk.pm',
	INSTALLDIRS  => 'site',
	SIGN         => 1,
	PL_FILES     => { },
	PREREQ_PM    => {
		'Test::Use::ok'  => 0,
		'Data::Swap'     => "0.07",
		'UNIVERSAL::ref' => 0,
	},
);

