use inc::Module::Install;

name            'Test-Dependencies';
author          'Zev Benjamin <zev@bestpractical.com>';
version_from        'lib/Test/Dependencies.pm';
license 'perl';
requires('Module::CoreList');
requires('Pod::Strip');

auto_install;
WriteAll;
