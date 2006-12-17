use Test::More tests => 1;

use base 'Class::DBI';

BEGIN {
use_ok( 'Class::DBI::GraphEasy' );
}

diag( "Testing Class::DBI::GraphEasy $Class::DBI::GraphEasy::VERSION, Perl 5.008006, /usr/local/bin/perl" );
