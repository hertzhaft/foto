#! /usr/bin/env perl
use Mojo::Base 'strict';
use Mojo::IOLoop;
use Mojo::Log;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::Util qw(decode encode);

use DDP;
use File::Path qw(make_path);
use JSON;
use Tie::IxHash;

my $enc = (split /\./, $ENV{LANG} || '' )[1];
my $input = $ARGV[0] || 'Borromini';
my $name = $enc ? encode('windows-1252', decode($enc, $input)) : $input;
my $agent = 'Mozilla/5.0 (X11; Linux x86_64; rv:81.0) Gecko/20100101 Firefox/81.0';
my $server = 'http://www.degruyter.com';
my $path = '/databasecontent';
my $params = [
    dbid => 'akl',
    dbf_0 => 'akl-name',
    dbsource => '/db/akl',
    dbt_0 => 'name',
    ];
my $data = [];

my $log = Mojo::Log->new;
my $ua = Mojo::UserAgent->new(max_redirects => 5);
my $delay = Mojo::IOLoop->delay();

$log->info("Searching $server for '$name'");

# setup URL
my $url = Mojo::URL->new($server)->path($path)->query($params);
$url->query([dbq_0 => $name]);
$ua->transactor->name($agent);

# fetch search results
my $tx = $ua->get($url);

# my $r = $tx->res->dom;
# p $r;

my $items = $tx->res->dom->find('div.contentItem');
die "Nothing found for '$name'\n" unless $items->size;

$items->each(\&getItem);

sub getItem {
	my ($item, $nr) = @_;
    my $title = $item->at('.itemTitle > a');
    # my $result = $_->at('.searchResultField');
    # my $sum = $result->at('summary');
    # my $text = $sum->at('localizations')->text;
    # my $date = $sum->child_nodes->last->text;
    my $artist = $title->text;
    my $link = $title->{href};
    followLink($artist, $link, $nr);
}

sub followLink {
    my ($artist, $link, $nr) = @_;
    my $_url = Mojo::URL->new("$server$link")->query(undef);
    $log->info("Found [$nr] '$artist' at $_url");
    my $done = $delay->begin;
    my $tx = $ua->get($_url => sub {
        my ($ua, $tx) = @_;
        my $items = $tx->res->dom->find('dl.dbfield');
        my $fields = {};
        my $tf = tie(%$fields, 'Tie::IxHash', Link => $_url->to_string);
        $items->each(sub {
            my $key = $_->at('b')->text;
            my $value = $_->at('dd')->text;
            $tf->Push($key => $value);
            });
        my $gnd = $fields->{'PND-ID'};
    		$gnd &&= 'gnd' . substr($gnd, 3);
        $tf->Unshift('Artist', join '; ', grep defined, $artist, $fields->{'Artist ID: '}, $gnd);
        $tf->Delete('Artist ID: ','PND-ID');
        $data->[$nr-1] = $fields;
        $done->();
        });
}

$delay->wait;
say JSON->new->utf8->pretty->encode($data);
