use inc::Module::Install;

name            'Test-Dependencies';
author          'Zev Benjamin <zev@bestpractical.com>';
version_from        'lib/Test/Dependencies.pm';
license 'perl';

requires('B::PerlReq');
requires('File::Find::Rule');
requires('Module::CoreList');
requires('PerlReq::Utils');
requires('Test::Builder::Module');
requires('YAML');

build_requires('Test::Builder::Tester');

auto_install;
WriteAll;
