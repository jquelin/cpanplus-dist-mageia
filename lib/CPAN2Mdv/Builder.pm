#
#
#

package CPAN2Mdv::Builder;

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
            '_build_completed'  => \&_onpriv_build_completed,
            '_build_continued'  => \&_onpriv_build_continued,
            '_start'            => \&_onpriv_start,
            'task'              => \&_onpub_task,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_task {
    my ($k, $h, $dist) = @_[KERNEL, HEAP, ARG0];

    my $spec = $dist->specfile;
    $k->post( 'journal', 'log', "task: $spec\n" );

    my $wheel = POE::Wheel::Run->new(
        Program     => [ 'rpmbuild', '-ba', $spec ],
        Priority    => +5,  # child process priority

        # i/o events
        StdoutEvent => '_build_continued',    # received data from the child's stdout.
        StderrEvent => '_build_continued',    # received data from the child's stderr.
    );

    my $wid = $wheel->ID;
    my $pid = $wheel->PID;
    $h->{wheel}{$wid}  = $wheel;                 # need to keep a ref to the wheel
    $h->{output}{$wid} = '';                     # initializing build output
    $h->{wid}{$pid}    = $wid;                   # storing pid
    $k->sig_child( $pid => "_build_completed" ); # wait for this child

    #$k->post( 'journal', 'log', "done: $spec\n" );
    #$k->post( 'main', 'builder_done', $dist );
}

#--
# private events


sub _onpriv_build_continued { $_[HEAP]->{output}{$_[ARG1]} .= "$_[ARG0]\n"; }

sub _onpriv_build_completed {
    my ($k, $h, $pid, $rv) = @_[KERNEL, HEAP, ARG1, ARG2];

    my $wid = delete $h->{wid}{$pid};       # remove pid
    my $out = delete $h->{output}{$wid};    # get build output
    delete $h->{wheel}{$wid};               # don't forget to release the wheel

    print "$out\n";
}

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'builder';

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
