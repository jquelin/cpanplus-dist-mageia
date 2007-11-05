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

use Test::More tests => 1;

require_ok( 'CPANPLUS::Dist::Mdv' );
diag( "Testing CPANPLUS::Dist::Mdv $CPANPLUS::Dist::Mdv::VERSION, Perl $], $^X" );

exit;
