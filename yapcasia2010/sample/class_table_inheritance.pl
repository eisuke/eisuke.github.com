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
            q{CREATE TABLE users ( id integer not null primary key, name text, type text)},
            q{ CREATE TABLE gold_users (
                id INTEGER NOT NULL PRIMARY KEY,
                point INTEGER NOT NULL,
                FOREIGN KEY(id) REFERENCES users(id)
              )},
        ],
    }),
);

{
    package User;
    use Any::Moose;

    has 'id'   => ( is => 'rw', isa => 'Int' );
    has 'name' => ( is => 'rw', isa => 'Str' );
    has 'type' => ( is => 'rw', isa => 'Maybe[Str]' );

    __PACKAGE__->meta->make_immutable;
};

{
    package User::Gold;
    use Any::Moose;
    extends 'User';

    has 'point' => ( is => 'rw', point => 'Int');

    __PACKAGE__->meta->make_immutable;
};

{
    package User::Silver;
    use Any::Moose;
    extends 'User';

    __PACKAGE__->meta->make_immutable;
};

my $user_table = $mapper->metadata->table( 'users' => 'autoload' );
my $gold_user_table = $mapper->metadata->table( 'gold_users' => 'autoload' );

$mapper->maps(
    $user_table => 'User',
    polymorphic_on => 'type',
);

$mapper->maps(
    $gold_user_table => 'User::Gold',
    polymorphic_identity => 'gold',
    inherits => 'User',
);

$mapper->maps(
    $user_table => 'User::Silver',
    polymorphic_identity => 'silver',
    inherits => 'User',
);

my $session = $mapper->begin_session( autocommit => 0 );
$session->add( User->new( name => 'normal user' ) );
$session->add( User::Gold->new( name => 'gold user', point => 100 ) );
$session->add( User::Silver->new( name => 'silver user' ) );
$session->commit;

my @all    = @{ $session->search('User')->execute };
my @gold   = @{ $session->search('User::Gold')->execute };
my @silver = @{ $session->search('User::Silver')->execute };

dd(@all, @gold, @silver );

dd( @{ $session->search('User')->with_polymorphic('*')->execute } );
