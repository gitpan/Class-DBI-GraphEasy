use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Class::DBI::GraphEasy',
    license             => 'perl',
    dist_author         => 'Xufeng Liang <danny@scm.uws.edu.au>',
    dist_version_from   => 'lib/Class/DBI/GraphEasy.pm',
    requires => {
    	'Graph::Easy' => 0,
        'Test::More' => 0,
        'Class::DBI' => 0,  # for tests
        'Class::ISA' => 0,
    },
    add_to_cleanup      => [ 'Class-DBI-GraphEasy-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
