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
        ],
    }),
);

{
    package User;
    use Moose;

    has 'id'   => ( is => 'rw', isa => 'Int' );
    has 'name' => ( is => 'rw', isa => 'Str' );
    has 'type' => ( is => 'rw', isa => 'Maybe[Str]' );

    __PACKAGE__->meta->make_immutable;
};

{
    package User::Gold;
    use Moose;
    extends 'User';

    __PACKAGE__->meta->make_immutable;
};

{
    package User::Silver;
    use Moose;
    extends 'User';

    __PACKAGE__->meta->make_immutable;
};

my $user_table = $mapper->metadata->table( 'users' => 'autoload' );

$mapper->maps(
    $user_table => 'User',
    polymorphic_on => 'type',
);

$mapper->maps(
    $user_table => 'User::Gold',
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
$session->add( User::Gold->new( name => 'gold user' ) );
$session->add( User::Silver->new( name => 'silver user' ) );
$session->commit;

my @all    = @{ $session->search('User')->execute };
my @gold   = @{ $session->search('User::Gold')->execute };
my @silver = @{ $session->search('User::Silver')->execute };

dd(@all, @gold, @silver );

dd( @{ $session->search('User')->with_polymorphic('*')->execute } );
