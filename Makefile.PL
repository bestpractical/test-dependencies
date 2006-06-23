use inc::Module::Install;

name            'Test-Dependencies';
all_from        'lib/Test/Dependencies.pm';

requires('Module::CoreList');
requires('Pod::Strip');

auto_install;
WriteAll;
