#!perl
use strict;
use warnings;
use lib "/home/e-oishi/work/dbix-objectmapper/lib";
use DBIx::ObjectMapper;
use DBIx::ObjectMapper::Engine::DBI;
use Data::Dump;

my $mapper = DBIx::ObjectMapper->new(
    engine => DBIx::ObjectMapper::Engine::DBI->new({
        dsn => 'DBI:SQLite:',
        username => undef,
        password => undef,
        on_connect_do => [
            q{ CREATE TABLE comments (
                id INTEGER NOT NULL PRIMARY KEY,
                comment TEXT,
                reply_to INTEGER REFERENCES comments(id)
            );},
        ],
        time_zone => 'Asia/Tokyo',
    }),
);

my $comment_table = $mapper->metadata->table('comments' => 'autoload');

$mapper->maps(
    $comment_table => 'Comment',
    constructor => { auto => 1 },
    accessors => { auto => 1 },
    attributes => {
        properties => {
            replies => {
                isa => $mapper->relation(
                    'has_many' => 'Comment'
                ),
            },
            parent => {
                isa => $mapper->relation(
                    'belongs_to' => 'Comment'
                ),
            }
        }
    }
);

my $session = $mapper->begin_session( autocommit => 0 );
my $first = Comment->new( comment => 'first comment' );
$session->add($first);
$session->commit;

my $second = Comment->new(
    comment => 'second comment',
    reply_to => $first->id,
);
$session->add($second);
$session->commit;

for my $reply ( @{$first->replies} ) {
    warn $reply->comment;
    warn $reply->parent->comment;
}
