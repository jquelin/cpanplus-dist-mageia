#
#
#

package CPAN2Mdv::Collector;

use strict;
use warnings;

use HTML::TreeBuilder;
use Pod::POM;
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
    my $name = $dist->name;

    $k->post( 'journal', 'log', "task: $name\n" );

    # fetch information
    my $pkgpage = "http://search.cpan.org/dist/$name/";
    my $html = qx[ curl --silent $pkgpage ];
    # FIXME: use poco-client-http

    my $tree = HTML::TreeBuilder->new_from_content($html);

    # version
    my $vers = $tree->look_down( _tag => 'td', class=>'cell')->as_trimmed_text;
    $vers =~ s/^$name-//;
    $dist->version($vers);

    # url
    my $url = $tree->look_down( _tag => 'a', sub {$_[0]->as_text eq 'Download' })->attr('href');
    $url = "http://search.cpan.org$url";
    $dist->url($url);

    # FIXME: license

    my $a = $tree->look_down( _tag=> 'a', sub {$_[0]->attr('href') =~ /\.pm$/ } );
    my $podurl = $pkgpage . $a->attr('href');
    my $podhtml = qx[ curl --silent $podurl ];
    # FIXME: use poco-client-http
    my $podtree = HTML::TreeBuilder->new_from_content($podhtml);
    my $srcurl = $podtree->look_down( _tag=>'a', sub {$_[0]->as_text eq 'Source' })->attr('href');
    $podtree->delete;
    $srcurl = 'http://search.cpan.org' . $srcurl;
    my $src = qx[ curl --silent $srcurl ];
    # FIXME: use poco-client-http
    my $parser = Pod::POM->new;
    my $pom = $parser->parse_text($src) || die $parser->error;
    foreach my $head1 ($pom->head1()) {
        my $title = $head1->title;
        if ( $title eq 'NAME' ) {
            my $content = $head1->content;
            $content =~ s/^[^-]+ - //;
            $dist->summary($content);
        }

        $dist->description($head1->content) if $title eq 'DESCRIPTION';
    }


    $tree->delete;

    # 
    my $pkg = "perl-$name";
    # FIXME: long rpm names (perl-Catalyst-P-A-Store-LDAP)
    $dist->pkgname($pkg);

    $k->post( 'journal', 'log', "done: $name-$vers\n" );
    $k->post( 'main', 'collector_done', $dist );
}


#--
# private events

sub _onpriv_start {
    my ($k, $h, $args) = @_[KERNEL, HEAP, ARG0];
    my $alias = 'collector';

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
