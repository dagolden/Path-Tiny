requires "Carp" => "0";
requires "Cwd" => "0";
requires "Digest" => "1.03";
requires "Digest::SHA" => "5.45";
requires "Exporter" => "5.57";
requires "Fcntl" => "0";
requires "File::Copy" => "0";
requires "File::Path" => "2.07";
requires "File::Spec" => "3.40";
requires "File::Temp" => "0.19";
requires "File::stat" => "0";
requires "constant" => "0";
requires "if" => "0";
requires "overload" => "0";
requires "perl" => "5.008001";
requires "strict" => "0";
requires "warnings" => "0";
recommends "Unicode::UTF8" => "0.58";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Basename" => "0";
  requires "File::Spec" => "3.40";
  requires "File::Spec::Functions" => "0";
  requires "File::Spec::Unix" => "0";
  requires "File::Temp" => "0.19";
  requires "Test::More" => "0.96";
  requires "lib" => "0";
  requires "open" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
  recommends "Test::FailWarnings" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5";
  requires "Dist::Zilla::Plugin::MinimumPerl" => "0";
  requires "Dist::Zilla::Plugin::OnlyCorePrereqs" => "0";
  requires "Dist::Zilla::Plugin::Prereqs" => "0";
  requires "Dist::Zilla::Plugin::RemovePrereqs" => "0";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0.068";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::More" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
  requires "Test::Spelling" => "0.12";
};
