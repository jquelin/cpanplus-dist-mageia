#
# This file is part of Audio::MPD
# Copyright (c) 2007 Jerome Quelin, all rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
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
    $h->{dist}{$wid}   = $dist;                  # storing dist
    $k->sig_child( $pid => "_build_completed" ); # wait for this child
}

#--
# private events


sub _onpriv_build_continued { $_[HEAP]->{output}{$_[ARG1]} .= "$_[ARG0]\n"; }

sub _onpriv_build_completed {
    my ($k, $h, $pid, $rv) = @_[KERNEL, HEAP, ARG1, ARG2];

    my $wid  = delete $h->{wid}{$pid};       # remove pid
    my $out  = delete $h->{output}{$wid};    # get build output
    my $dist = delete $h->{dist}{$wid};      # get dist object
    delete $h->{wheel}{$wid};                # don't forget to release the wheel

    if ( $out =~ /^error:/m ) {
        # oops, there were some errors.
        my $name = $dist->name;

        if ( $out =~ /^error: Failed build dependencies:\n(.*)\z/ms ) {
            # additional modules to be packaged.
            my $wanted = $1;
            my @modules;
            foreach my $m ( $wanted =~ /perl\((.+?)\)/g ) {
                my $new = CPAN2Mdv::Dist->new({module=>$m, is_prereq=>$dist});
                $k->post( 'main', 'need_module', $new );
                # FIXME: keep track of all dependencies for a module
                push @modules, $m;
            }
            $k->post( 'journal', 'log', "hold: $name needs " . join(',', @modules) . "\n" );
            return;
        }

        if ( $out =~ /Can't locate (\S+)\.pm in \@INC/ ) {
            # missing prereq.
            my $prereq = $1; $prereq =~ s!/!::!g;
            #my @prereqs = @{ $dist->build_requires };
            #push @prereqs, $prereq;
            #$dist->build_requires();

            my $new = CPAN2Mdv::Dist->new({module=>$prereq, is_prereq=>$dist});
            $k->post( 'journal', 'log', "hold: $name needs $prereq\n" );
            $k->post( 'main', 'need_module', $new );
            return;
        }
        
        if ( $out =~ /^\s+Installed .but unpackaged. file.s. found:\n(.*)\z/ms ) {
            # additional file to be packaged.
            my $files = $1;
            $files =~ s/^\s+//mg; # remove spaces
            my @files = split /\n/, $files;
            $dist->extra_files( \@files );
            $k->post( 'journal', 'log', "hold: $name needs respec (missing files)\n" );
            $k->post( 'main', 'need_respec', $dist );
            return;
        }

        print ">>>>>>> ERROR\n$out";
        # FIXME: deal with error
        return;
    }

    my $pkgname = $dist->pkgname;
    my ($rpm)  = glob "$ENV{HOME}/rpm/RPMS/*/$pkgname-*.rpm";
    my ($srpm) = glob "$ENV{HOME}/rpm/SRPMS/$pkgname-*.src.rpm";
    $dist->rpm( $rpm );
    $dist->srpm( $srpm );
    $k->post( 'journal', 'log', "done: $srpm\n" );
    $k->post( 'main', 'builder_done', $dist );
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
