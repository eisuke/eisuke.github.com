#!perl
use strict;
use warnings;
use DBIx::ObjectMapper;
use DBIx::ObjectMapper::Engine::DBI;
use Data::Dump;

my $mapper = DBIx::ObjectMapper->new(
    engine => DBIx::ObjectMapper::Engine::DBI->new({
        dsn => 'DBI:SQLite:',
        username => undef,
        password => undef,
        on_connect_do => [
            q{CREATE TABLE tweets ( id integer primary key, tweet text, created timestamp not null default now )}
        ],
        time_zone => 'Asia/Tokyo',
    }),
);

my $tweets = $mapper->metadata->table( 'tweets' => 'autoload' );

{
    package Tweet;
    use Mouse;
    use String::Filter;
    use HTML::Entities;
    use URI::Escape;

    my $sf = String::Filter->new(
        default_rule => sub {
            my $text = shift;
            encode_entities($text);
        },
    );

    # URL の変換ルールを登録
    $sf->add_rule(
        'http://[A-Za-z0-9_\\-\\~\\.\\%\\?\\#\\@/]+',
        sub {
            my $url = shift;
            sprintf(
                '<a href="%s">%s</a>',
                encode_entities($url),
                encode_entities($url),
            );
        },
    );

    # @user の変換ルールを登録
    $sf->add_rule(
        '(?:^|\\s)\\@[A-Za-z0-9_]+',
        sub {
            $_[0] =~ /^(.*?\@)(.*)$/;
            my ($prefix, $user) = ($1, $2);
            sprintf(
                '%s<a href="http://twitter.com/%s">%s</a>',
                encode_entities($prefix),
                encode_entities($user),
                encode_entities($user),
            );
        },
    );

    # #hashtag の変換ルールを登録
    $sf->add_rule(
        '(?:^|\\s)#[A-Za-z0-9_]+',
        sub {
            $_[0] =~ /^(.?)(#.*)$/;
            my ($prefix, $hashtag) = ($1, $2);
            sprintf(
                '%s<a href="http://twitter.com/search?q=%s">%s</a>',
                encode_entities($prefix),
                encode_entities(uri_escape($hashtag)),
                encode_entities($hashtag),
            );
        },
    );


    has 'id' => ( is => 'rw' );
    has 'tweet' => ( is => 'rw' );
    has 'created' => ( is => 'rw' );

    sub filter_tweet { $sf->filter($_[0]->tweet) }

    __PACKAGE__->meta->make_immutable;
};

$mapper->maps( $tweets => 'Tweet' );


{
    my $session = $mapper->begin_session( autocommit => 0, no_cache => 1 );
    $session->add( Tweet->new( tweet => 'Hello!' ) );
    $session->commit;

    my $t = $session->get( 'Tweet' => 1 );
    warn $t->id;
    warn $t->tweet;
    warn $t->created;
    $t->tweet( 'Hello, @eisukeoishi ! #followme http://exmaple.com/' );
    $session->commit;

    warn $t->filter_tweet;

    $session->delete($t);
    $session->commit;

};
