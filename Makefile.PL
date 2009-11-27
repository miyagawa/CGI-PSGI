use inc::Module::Install;
name 'CGI-PSGI';
all_from 'lib/CGI/PSGI.pm';

requires 'CGI', '3.00';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
