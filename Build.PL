
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'File::Find' => '0',
    'File::Temp' => '0',
    'Module::Build' => '0.3601',
    'Test::More' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'a cpanplus backend to build mageia rpms',
  'dist_author' => [
    'Jerome Quelin'
  ],
  'dist_name' => 'CPANPLUS-Dist-Mageia',
  'dist_version' => '1.111720',
  'license' => 'perl',
  'module_name' => 'CPANPLUS::Dist::Mageia',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'CPANPLUS::Dist::Base' => '0',
    'CPANPLUS::Error' => '0',
    'File::Basename' => '0',
    'File::Copy' => '0',
    'File::ShareDir' => '0',
    'File::Slurp' => '0',
    'IPC::Cmd' => '0',
    'List::MoreUtils' => '0',
    'List::Util' => '0',
    'POSIX' => '0',
    'Pod::POM' => '0',
    'Pod::POM::View::Text' => '0',
    'Readonly' => '0',
    'Text::Wrap' => '0',
    'perl' => '5.010'
  },
  'script_files' => [],
  'share_dir' => {
    'dist' => 'share'
  }
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
