#!perl

use Test::Builder::Tester tests => 2;
require Test::Dependencies;

chdir "t-data/with-exclude";
{
    Test::Dependencies->import;
    test_out("not ok 1 - Could not determine modules used in 'lib/IgnoreMe.pm'");
    test_fail(+2);
    test_out("ok 2 - META.yml is present and readable");
    ok_dependencies();
    test_test("Includes lib/IgnoreMe.pm by default");
}
{
    Test::Dependencies->import(file_exclude => qr/Ignore/);
    test_out("ok 1 - META.yml is present and readable");
    ok_dependencies();
    test_test("Excluding qr/Ignore/ causes tests to pass");
}

