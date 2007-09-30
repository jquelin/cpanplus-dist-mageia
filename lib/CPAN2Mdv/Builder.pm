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
            '_build_continued'  => \&_onpriv_build_continued,
            '_build_finished'   => \&_onpriv_build_finished,
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

        # Define I/O events to emit.  Most are optional.
        StdoutEvent => '_build_continued',    # Received data from the child's STDOUT.
        StderrEvent => '_build_continued',    # Received data from the child's STDERR.
        #CloseEvent  => 'child_closed',  # Child closed all output handles.

        # Optionally specify different I/O formats.
        #StdoutFilter => POE::Filter::Line->new(), # Child output is a stream.
        #StderrFilter => POE::Filter::Line->new(),   # Child errors are lines.
    );

    my $wid = $wheel->ID;
    my $pid = $wheel->PID;
    $h->{wheel}{$wid}  = $wheel;                # need to keep a ref to the wheel
    $h->{output}{$wid} = '';
    $h->{wid}{$pid}    = $wid;
    $k->sig_child( $pid => "_build_finished" ); # wait for this child

    #$k->post( 'journal', 'log', "done: $spec\n" );
    #$k->post( 'main', 'builder_done', $dist );
}

#--
# private events


sub _onpriv_build_continued { $_[HEAP]->{output}{$_[ARG1]} .= "$_[ARG0]\n"; }

sub _onpriv_build_finished {
    my ($k, $h, $pid, $rv) = @_[KERNEL, HEAP, ARG1, ARG2];

    my $wid = delete $h->{wid}{$pid};
    my $out = delete $h->{output}{$wid};
    delete $h->{wheel}{$wid}; # don't forget to release the wheel

    print ">>>>>>>>>>><\n";
    print $out;
    #$k->sig_handled();
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
