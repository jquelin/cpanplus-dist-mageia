#!perl
#
# This file is part of CPANPLUS::Dist::Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

BEGIN { require 5.008; }
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'CPANPLUS::Dist::Mdv',
    AUTHOR              => 'Jerome Quelin <jquelin@cpan.org>',
    VERSION_FROM        => 'lib/CPANPLUS/Dist/Mdv.pm',
    ABSTRACT_FROM       => 'lib/CPANPLUS/Dist/Mdv.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'CPANPLUS'             => 0,
        'File::Slurp'          => 0,
        'IPC::Cmd'             => 0,
        'Pod::POM'             => 0,
        'Pod::POM::View::Text' => 0,
        'POSIX'                => 0,
        'Readonly'             => 0,
        'Test::More'           => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => [
                'CPANPLUS-Dist-Mdv-*', 'MANIFEST.bak',
                map { ( '*/' x $_ ) . '*~' } 0..5
        ] },
);
