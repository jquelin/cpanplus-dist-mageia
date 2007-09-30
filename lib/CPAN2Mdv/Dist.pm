#
#
#

package CPAN2Mdv::Dist;

use strict;
use warnings;

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors
    ( qw[ description extra_files is_prereq name module path pkgname rpm
        specfile summary url version ] );

1;
__END__
