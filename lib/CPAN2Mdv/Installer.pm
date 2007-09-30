#
#
#

package CPAN2Mdv::Installer;

use strict;
use warnings;

use POE;
use POE::Wheel::Run;



#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_install_completed' => \&_onpriv_install_completed,
            '_install_continued' => \&_onpriv_install_continued,
            '_start'             => \&_onpriv_start,
            'task'               => \&_onpub_task,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_task {
    my ($k, $h, $dist) = @_[KERNEL, HEAP, ARG0];

    my $rpm = $dist->rpm;
    $k->post( 'journal', 'log', "task: $rpm\n" );

    my $wheel = POE::Wheel::Run->new(
        Program     => $h->{conf}{installer}{command} . " $rpm",
        Priority    => +5,  # child process priority

        # i/o events
        StdoutEvent => '_install_continued',    # received data from the child's stdout.
        StderrEvent => '_install_continued',    # received data from the child's stderr.
    );

    my $wid = $wheel->ID;
    my $pid = $wheel->PID;
    $h->{wheel}{$wid}  = $wheel;                   # need to keep a ref to the wheel
    $h->{output}{$wid} = '';                       # initializing build output
    $h->{wid}{$pid}    = $wid;                     # storing pid
    $h->{dist}{$wid}   = $dist;                    # storing dist
    $k->sig_child( $pid => "_install_completed" ); # wait for this child
}


#--
# private events

sub _onpriv_install_continued { $_[HEAP]->{output}{$_[ARG1]} .= "$_[ARG0]\n"; }

sub _onpriv_install_completed {
    my ($k, $h, $pid, $rv) = @_[KERNEL, HEAP, ARG1, ARG2];

    my $wid  = delete $h->{wid}{$pid};       # remove pid
    my $out  = delete $h->{output}{$wid};    # get build output
    my $dist = delete $h->{dist}{$wid};      # get dist object
    delete $h->{wheel}{$wid};                # don't forget to release the wheel

    my $name = $dist->name;
    if ( $rv != 0 ) {
        # oops, there were some errors.

        print ">>>>>>> ERROR\n$out";
        # FIXME: deal with error
        return;
    }

    # report success
    $k->post( 'journal', 'log', "done: $name installed\n" );
    $k->post( 'main', 'installer_done', $dist );
}



sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'installer';

    # store config.
    $h->{conf}  = $args;

    # set alias and finish startup.
    $k->alias_set( $alias );
    $k->post( 'journal', 'ident',      $alias );       # register to journal
    $k->post( 'main',    'rendezvous', $alias );       # signal main that we're started
    $k->post( 'journal', 'log', "start complete\n" );  # logging
}



1;
__END__
