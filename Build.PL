#!perl
#
# This file is part of CPANPLUS::Dist::Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use strict;
use warnings;

use Module::Build;

my %requires = (
    'CPANPLUS'             => 0,
    'CPANPLUS::Error'      => 0,
    'File::Basename'       => 0,
    'File::Copy'           => 0,
    'File::Slurp'          => 0,
    'IPC::Cmd'             => 0,
    'List::Util'           => 0,
    'List::MoreUtils'      => 0,
    'Pod::POM'             => 0,
    'Pod::POM::View::Text' => 0,
    'POSIX'                => 0,
    'Readonly'             => 0,
    'Text::Wrap'           => 0,
    'perl'                 => '5.008',
);
my %build_requires = (
    %requires,
    'Test::More' => 0,
);
 my %recommends = (
     'Test::Pod'           => 0,
     'Test::Pod::Coverage' => 0,
);


my $builder = Module::Build->new (
    module_name         => 'CPANPLUS::Dist::Mdv',
    dist_author         => 'Jerome Quelin <jquelin@cpan.org>',
    license             => 'perl',
    dist_version_from   => 'lib/CPANPLUS/Dist/Mdv.pm',
    script_files        => [ ],
    build_requires      => \%build_requires,
    requires            => \%requires,
    recommends          => \%recommends,
    create_makefile_pl  => 'traditional',
    add_to_cleanup      => [
        'CPANPLUS-Dist-Mdv-*', 'MANIFEST.bak',
        map { ( '*/' x $_ ) . '*~' } 0..5
    ],
    meta_merge          => {
        resources => {
            repository => 'http://repo.or.cz/w/cpanplus-dist-mdv.git',
        },
    },
);

$builder->create_build_script();
