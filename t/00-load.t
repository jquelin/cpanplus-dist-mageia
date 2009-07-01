#!perl
#
# This file is part of CPANPLUS::Dist::Mdv.
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
#

use 5.010;
use strict;
use warnings;

use File::Find::Rule;
use Test::More;
use Test::Script;

my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');
plan tests => scalar(@files);

foreach my $file ( @files ) {
    my $module = $file;
    $module =~ s/[\/\\]/::/g;
    $module =~ s/\.pm$//;
    is( qx{ $^X -M$module -e "print '$module ok'" }, "$module ok", "$module loaded ok" );
}
