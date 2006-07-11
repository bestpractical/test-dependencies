#!perl -T

use Test::Builder::Tester;
use Test::More tests => 1;

BEGIN {
  test_pass("use Test::Dependencies;");
  use_ok('Test::Dependencies');
  test_test("use Test::Dependencies;");
}
