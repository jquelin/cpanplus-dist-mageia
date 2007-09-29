#
#
#

package CPAN2Mdv::DistFinder;

use POE;



#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'    => \&_onpriv_start,
            'resolve'   => \&_onpub_resolve,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_resolve {
    my $a = $_[ARG0];
    print "$a\n";
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'distfinder';

    # store config
    $h->{conf}  = $args;
    my $pkgfile = $h->{conf}{General}{cache} . '/02packages.details.txt';
    open my $pkgfh, '<', $pkgfile or die "can't open '$pkgfile': $!";
    $h->{pkgfh} = $pkgfh;

    $k->alias_set( $alias );
    $k->post( 'journal', 'ident',      $alias );       # register to journal
    $k->post( 'main',    'rendezvous', $alias );       # signal main that we're started
    $k->post( 'journal', 'log', "start complete\n" );  # logging
}



1;
__END__
