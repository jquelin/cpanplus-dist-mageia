#
#
#

package CPAN2Mdv::Dist;

use strict;
use warnings;

use base qw[ Class::Accessor::Fast ];
__PACKAGE__->mk_accessors
    ( qw[ extra_files is_prereq name module path pkgname rpm specfile url version ] );

1;
__END__
