package MooseX::Role::DBIC;
# ABSTRACT: make your Moose class encapsulate one or more DBIC schemas

use Class::MOP;
use MooseX::Role::Parameterized;

parameter 'schema_name' => qw(
    is      ro
    isa     Str
    default dbic
);

parameter 'schema_class' => qw(
    is       ro
    isa      Str
    required 1
);

parameter 'schema_description' => (
    is  => 'ro',
    isa => 'Str',
    lazy_build => 1,
   );
# builder for schema_description needs to do in the params metaclass,
# not this package's one.  bleh.
__PACKAGE__->meta->parameters_metaclass->add_method(
   _build_schema_description => sub {
       my $n = shift->schema_name;
       $n =~ s/_/ /g;
       return $n;
   });

parameter 'accessor_options' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

role {

    my $p        = shift;
    my $name     = $p->schema_name;
    my $class    = $p->schema_class;
    my $desc     = $p->schema_description;
    my $acc_opts = $p->accessor_options;
    my $clearer  = sub { shift->${\"clear_${name}_schema"}() };

    # most of the accessors have a trigger to clear the lazily-built
    # schema on write, and also need to get their accessor opts if
    # present
    my $common_opts = sub {
        return (
            trigger => $clearer,
            @{ $acc_opts->{"${name}_".shift} || [] },
        );
    };

    has "${name}_dsn" => (
        documentation => "DBI dsn for connecting to the $desc",
        isa           => 'Str',
        is            => 'rw',
        required      => 1,
        $common_opts->('dsn'),
       );
    has "${name}_user" => (
        documentation  => "username for connecting to the $desc",
        isa            => 'Str',
        is             => 'rw',
        $common_opts->('user'),
       );
    has "${name}_password" => (
        documentation => "password for connecting to the $desc",
        isa           => 'Str',
        is            => 'rw',
        $common_opts->('password'),
       );

    has "${name}_attrs" => (
        documentation => "hashref of DBI attributes for connecting to $desc",
        is            => 'rw',
        isa           => 'HashRef',
        default       => sub { {} },
        $common_opts->('attrs'),
       );

    # provides a lazy *_schema attr
    has "${name}_schema" => (
        is  => 'rw',
        isa => 'Object',
        lazy_build => 1,
        @{ $acc_opts->{"${name}_schema"} || [] },
        );

    has "${name}_schema_options" => (
        is      => 'rw',
        isa     => 'HashRef',
        default => sub { {} },
        $common_opts->('schema_options'),
      );

    method "_build_${name}_schema" => sub {
        my ( $self ) = @_;

        Class::MOP::load_class( $class );

        no strict 'refs';

        return $class->connect(
            $self->${\"${name}_dsn"}(),
            $self->${\"${name}_user"}(),
            $self->${\"${name}_password"}(),
            $self->${\"${name}_attrs"}(),
            $self->${\"${name}_schema_options"}(),
          );
    };
}


__END__

=head1 SYNOPSIS

  ### simplest case

  package MyClass;
  use Moose;

  with 'MooseX::Role::DBIC' => { schema_class => 'My::Schema' };

  package main;
  my $x = MyClass->new( dbic_dsn  => '...',
                        dbic_user => '...',
                        dbic_password => '...',
                       );

  $x->dbic_schema->resultset('Foo')->search(...);

  ##############
  ### a more complicated use case:
  ###    BigClass has 2 different schemas, an 'itchy_schema' and a
  ###    'scratchy_schema'

  package BigClass;
  use Moose;

  with 'MooseX::Role::DBIC' => {
      schema_name  => 'itchy',
      schema_class => 'Itchy::Schema',
  };

  with 'MooseX::Role::DBIC' => {
      schema_name  => 'scratchy',
      schema_class => 'Scratchy::Schema',
  };

  # 2 database connections can take a lot of parameters ...
  my $c = BigClass->new(
      itchy_dsn  => 'dbi:Pg:dbname=foo;host=bar',
      itchy_user => 'mikey',
      itchy_password => 'seekrit',
      itchy_attrs    => { AutoCommit => 1 },
      itchy_schema_options => {
          on_connect_do => 'set search_path=foo,bar,public',
      },

      scratchy_dsn   => 'dbi:SQLite:dbname=somefile',
     );

  $c->itchy_schema->resultset(...);
  $c->scratchy_schema->resultset(...);

=head1 DESCRIPTION

Generic parameterized Moose role to give your class accessors for
managing one or more L<DBIx::Class::Schema> objects.

Can be composed with L<MooseX::Role::DBIx::Connector> to share the
same dsn, user, password, and connection attributes.

=head1 ROLE PARAMETERS

=head1 schema_name

Name for this connection, which is the prefix for all the generated
accessors.  Default 'dbic', which means that you get the accessors
C<dbic_dsn>, C<dbic_user>, C<dbic_password>, C<dbic_attrs>, and
C<dbic_conn>.

=head1 schema_description

Plaintext description of this connection.  Only used in generating
C<documentation> for each of the generated accessors.

=head1 accessor_options

Hashref of additional options to pass to the generated accessors, e.g.

  package MyClass;
  use Moose;
  with 'MooseX::Role::DBIC' => {
    schema_name  => 'itchy',
    accessor_options => {
        'itchy_dsn'  => [ traits  => ['GetOpt'] ],
        'itchy_user' => [ default => 'minnie_the_moocher'   ],
    },
  };

=head1 ATTRIBUTES

=head2 (schema_name)_schema

Get a L<DBIx::Connector> schema object for the given schema info.
This is the most important one.

=head2 (schema_name)_dsn

L<DBI> DSN for your schema.  Required.

=head2 (schema_name)_user

Username for the schema.

=head2 (schema_name)_password

Password for the schema.

=head2 (schema_name)_attrs

Hashref of L<DBI> attributes for the schema.  Passed to
L<DBIx::Class::Schema-&gt;connect>, which passes them to L<DBI>'s
connect()

=head2 (schema_name)_schema_options

Hashref of other attributes for the schema.  Passed to
L<DBIx::Class::Schema-&gt;connect>.
