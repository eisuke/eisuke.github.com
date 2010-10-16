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
            q{CREATE TABLE users ( id INTEGER NOT NULL PRIMARY KEY,name TEXT);},
            q{CREATE TABLE issues (id INTEGER NOT NULL PRIMARY KEY, title TEXT);},
            q{CREATE TABLE user_issues( user_id INTEGER NOT NULL REFERENCES users(id), issue_id  INTEGER NOT NULL REFERENCES issues(id))},
        ],
        time_zone => 'Asia/Tokyo',
    }),
);

my $user_table = $mapper->metadata->table( 'users' => 'autoload' );
my $issue_table = $mapper->metadata->table( 'issues' => 'autoload' );
my $user_issue_table = $mapper->metadata->t( 'user_issues' => 'autoload');


{
    package User;
    use Any::Moose;

    has 'id'        => ( is => 'rw', isa => 'Int' );
    has 'name'      => ( is => 'rw', isa => 'Str' );
    has 'issues'    => ( is => 'rw', isa => 'Maybe[ArrayRef[Issue]]');

    __PACKAGE__->meta->make_immutable;
};

$mapper->maps(
    $issue_table => 'Issue',
    constructor => { auto => 1 },
    accessors   => { auto => 1 },
    # attributes => {
    #     properties => {
    #         users => {
    #             isa => $mapper->relation(
    #                 many_to_many => $user_issue_table => 'User',
    #                 { cascade => 'all' },
    #             ),
    #         }
    #     }
    # }
);

$mapper->maps(
    $user_table => 'User',
    attributes  => {
        properties => {
            issues => {
                isa => $mapper->relation(
                    many_to_many => $user_issue_table => 'Issue',
                )
            }
        }
    }
);

my $session = $mapper->begin_session( autocommit => 0 );
$session->add( User->new( name => 'name1' ) );
my @issues = (
    Issue->new( title => 'issue1' ),
    Issue->new( title => 'issue2' ),
    Issue->new( title => 'issue3' ),
);
$session->add_all(@issues);
$session->commit;

my $user = $session->get( 'User' => 1 );
push @{$user->issues}, @issues;
$session->commit;

my $new_issue = $session->add(Issue->new( title => 'issue4' ));
push @{$user->issues}, $new_issue;
$session->commit;

for my $i ( @{$user->issues}) {
    print $i->title . $/;
}
