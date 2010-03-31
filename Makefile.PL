use inc::Module::Install;
name 'CGI-PSGI';
all_from 'lib/CGI/PSGI.pm';

requires 'CGI', '3.15';

build_requires 'Test::More';
author_tests('xt');
auto_set_repository;
WriteAll;
