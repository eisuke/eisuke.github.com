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
            q{ CREATE TABLE users (
                id INTEGER NOT NULL PRIMARY KEY,
                name TEXT
            )},
            q{ CREATE TABLE address (
              id INTEGER NOT NULL PRIMARY KEY,
              user_id INTEGER NOT NULL REFERENCES users(id),
              address TEXT)}
        ],
        time_zone => 'Asia/Tokyo',
    }),
);

my $user_table = $mapper->metadata->table('users'=>'autoload');
my $addr_table = $mapper->metadata->table('address' => 'autoload');

$mapper->maps(
    $user_table => 'User',
    constructor => { auto => 1 },
    accessors   => { auto => 1 },
    attributes  => {
        properties => {
            addresses => {
                isa => $mapper->relation(
                    has_many => 'Address',
                    { order_by => $addr_table->c('id') }
                ),
            },
        }
    }
);

$mapper->maps(
    $addr_table => 'Address',
    constructor => { auto => 1 },
    accessors   => { auto => 1 },
);

my $session = $mapper->begin_session( autocommit => 0 );
$session->add(
    User->new(
        name => 'name1',
        addresses => [
            Address->new( address => '東京都中野区' ),
            Address->new( address => '東京都渋谷区' ),
            Address->new( address => '東京都新宿区' ),
            Address->new( address => '東京都中央区' ),
        ],
    )
);

$session->commit;

my $attr = $mapper->attribute('User');
my $it = $session->search('User')
    ->filter( $attr->prop('addresses.address')->like('%東京都%') )->execute;

while( my $u = $it->next ) {
    warn $u->id;
}

my $it2 = $session->search('User')->eager( $attr->prop('addresses') )->execute;
while( my $u = $it2->next ) {
    dd $u->id;
    dd $u->addresses;
}

undef($session);
$session = $mapper->begin_session( autocommit => 0 );

dd $session->get( 'User' => 1, { eagerload => 'addresses' } );






