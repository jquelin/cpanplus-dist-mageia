#
#
#

package CPAN2Mdv::Specifier;

use strict;
use warnings;

use POE;



#--
# constructor

sub spawn {
    my ($type, $args) = @_;

    my $session = POE::Session->create(
        args          => [ $args ],
        inline_states => {
            '_start'  => \&_onpriv_start,
            'task'    => \&_onpub_task,
        },
    );
    return $session->ID;
}


#--
# public events

sub _onpub_task {
    my ($k, $h, $dist) = @_[KERNEL, HEAP, ARG0];

    my $name    = $dist->name;
    my $vers    = $dist->version;
    my $summary = $dist->summary;
    my $descr   = $dist->description;
    my $url     = $dist->url;
    $k->post( 'journal', 'log', "task: $name-$vers\n" );

    my $pkg = $dist->pkgname;
    my $spec = "$ENV{HOME}/rpm/SPECS/$pkg.spec";
    $dist->specfile($spec);

    my @docfiles;
    {
        my $tarball = $dist->path;
        open my $tarfh, '-|', "tar ztvf $tarball" or die "can't open '$tarball': $!";
        while ( defined( my $line = <$tarfh> ) ) {
            next unless $line =~ /(README|Change(s|log)|LICENSE|META.yml)$/i;
            push @docfiles, $1;
        }
        close $tarfh;
    }

    #
    unlink $spec;
    my $template = $h->{conf}{specifier}{template};
    open my $tplfh,  '<', $template or die "can't open '$template': $!";
    open my $specfh, '>', $spec     or die "can't open '$spec': $!";
    while ( defined( my $line = <$tplfh> ) ) {
        $line =~ s/DISTNAME/$name/;
        $line =~ s/DISTVERS/$vers/;
        $line =~ s/DISTSUMMARY/$summary/;
        $line =~ s/DISTURL/$url/;
        $line =~ s/DISTDESCR/$descr/;
        $line =~ s/DISTDOC/@docfiles ? "%doc @docfiles" : ''/e;
        $line =~ s/DISTEXTRA/join( "\n", @{ $dist->extra_files || [] })/e;

        print $specfh $line;
    }
    close $specfh;
    close $tplfh;

    $k->post( 'journal', 'log', "done: $spec\n" );
    $k->post( 'main', 'specifier_done', $dist );
}

#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'specifier';

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
