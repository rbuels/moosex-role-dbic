use strict;
use warnings;

use Test::More tests => 10;

my $t = Tester->new( dbic_dsn => 'DSN, baby!' );
isa_ok( $t, 'Tester' );
is( $t->dbic_dsn, 'DSN, baby!' );
isa_ok( $t->dbic_schema, 'MockSchema' );

# test clearing trigger, should call connect() again (which is
# checked by the test count)
$t->dbic_schema_options( { foo => 'bar' } );
isa_ok( $t->dbic_schema, 'MockSchema' );
is_deeply( $t->dbic_schema_options, { foo => 'bar' } );

my $herp = Tester2->new;
is( $herp->herp_dsn, 'herpdsn!', 'accessor options work' );
isa_ok( $herp->herp_schema, 'MockSchema' );

exit;


BEGIN {
    package Tester;
    use Moose;
    with 'MooseX::Role::DBIC' => { schema_class => 'MockSchema' };

    package Tester2;
    use Moose;
    with 'MooseX::Role::DBIC' => {
        schema_name => 'herp',
        schema_class => 'MockSchema',
        accessor_options => {
            herp_dsn => [ default => 'herpdsn!' ],
        },
    };

    package MockSchema;

    sub connect {
        my ( $class, @info ) = @_;
        Test::More::ok( 1, 'connect called!' );
        return bless {}, $class;
    }

}
