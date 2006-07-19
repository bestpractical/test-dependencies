#!perl -T

use Test::Builder::Tester;
use Test::More tests => 1;

BEGIN {
  test_out("ok 1 - use Test::Dependencies;");
  use_ok( 'Test::Dependencies', 'exclude',
          [qw/Some::Namespace Some::Other::Namespace/] );
  test_test("use Test::Dependencies;");
}
