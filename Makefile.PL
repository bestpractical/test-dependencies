use inc::Module::Install;

name            'Test-Dependencies';
author          'Zev Benjamin <zev@cpan.com>';
version_from        'lib/Test/Dependencies.pm';
license 'perl';

requires('B::PerlReq');
requires('File::Find::Rule');
requires('IPC::Cmd');
requires('Module::CoreList');
requires('PerlReq::Utils');
requires('Pod::Strip');
requires('Test::Builder::Module');
requires('YAML');

build_requires('Test::Builder::Tester' => 0.64);

no_index directory => "t-data";

auto_install;
WriteAll;
