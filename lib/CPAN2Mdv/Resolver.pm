#
#
#

package CPAN2Mdv::Resolver;

use POE;



#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'  => \&_onpriv_start,
            'resolve' => \&_onpub_resolve,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_resolve {
    my ($k, $h, $module) = @_[KERNEL, HEAP, ARG0];

    $k->post( 'journal', 'log', "task: $module\n" );

    # reset file handler.
    my $pkgfh = $h->{pkgfh};
    seek $pkgfh, 0, 0;
    while ( defined(my $line = <$pkgfh>) ) {
        next unless $line =~ /^$module\s/;

        # found module
        chomp $line;
        my (undef, undef, $dist) = split /\s+/, $line;
        $dist =~ s!^.*/!!;    # clean author
        $dist =~ s/-\d.*$//;  # clean version
        $k->post( 'journal', 'log', "done: $dist\n" );
        $k->post( 'main', 'resolved', $dist );
        return;
    }

    # FIXME: rerport error
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'resolver';

    # store config.
    $h->{conf}  = $args;
    # FIXME: download+update at given freq
    my $pkgfile = $h->{conf}{General}{cache} . '/02packages.details.txt';
    open my $pkgfh, '<', $pkgfile or die "can't open '$pkgfile': $!";
    $h->{pkgfh} = $pkgfh;

    # set alias and finish startup.
    $k->alias_set( $alias );
    $k->post( 'journal', 'ident',      $alias );       # register to journal
    $k->post( 'main',    'rendezvous', $alias );       # signal main that we're started
    $k->post( 'journal', 'log', "start complete\n" );  # logging
}



1;
__END__
