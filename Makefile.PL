#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME         => 'Data::Thunk',
	VERSION_FROM => 'lib/Data/Thunk.pm',
	INSTALLDIRS  => 'site',
	SIGN         => 1,
	PL_FILES     => { },
	PREREQ_PM    => {
		'Test::use::ok'  => 0,
		'Test::More' => '0.88',
		'Try::Tiny' => 0,
		'Data::Swap'     => "0.07",
		'UNIVERSAL::ref' => 0,
		'namespace::clean' => "0.08",
		'Sub::Exporter' => 0,
	},
);

