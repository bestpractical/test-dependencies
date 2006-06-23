use inc::Module::Install;

name            'Test-Dependencies';
all_from        'lib/Test/Dependencies.pm';

#requires('');

auto_install;
WriteAll;
