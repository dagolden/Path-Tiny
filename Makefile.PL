
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.025.
use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker 6.17;



my %WriteMakefileArgs = (
  "ABSTRACT" => "File path utility",
  "AUTHOR" => "David Golden <dagolden\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "Path-Tiny",
  "EXE_FILES" => [],
  "LICENSE" => "apache",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "Path::Tiny",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "Digest" => "1.03",
    "Digest::SHA" => "5.45",
    "Exporter" => "5.57",
    "Fcntl" => 0,
    "File::Copy" => 0,
    "File::Path" => "2.07",
    "File::Spec" => "3.40",
    "File::Temp" => "0.19",
    "File::stat" => 0,
    "constant" => 0,
    "if" => 0,
    "overload" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Basename" => 0,
    "File::Spec" => "3.40",
    "File::Spec::Functions" => 0,
    "File::Spec::Unix" => 0,
    "File::Temp" => "0.19",
    "Test::More" => "0.96",
    "lib" => 0,
    "open" => 0
  },
  "VERSION" => "0.061",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Cwd" => 0,
  "Digest" => "1.03",
  "Digest::SHA" => "5.45",
  "Exporter" => "5.57",
  "ExtUtils::MakeMaker" => "6.17",
  "Fcntl" => 0,
  "File::Basename" => 0,
  "File::Copy" => 0,
  "File::Path" => "2.07",
  "File::Spec" => "3.40",
  "File::Spec::Functions" => 0,
  "File::Spec::Unix" => 0,
  "File::Temp" => "0.19",
  "File::stat" => 0,
  "Test::More" => "0.96",
  "constant" => 0,
  "if" => 0,
  "lib" => 0,
  "open" => 0,
  "overload" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



HASH(0x7fc4991968d8)
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.025.
use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker 6.17;



my %WriteMakefileArgs = (
  "ABSTRACT" => "File path utility",
  "AUTHOR" => "David Golden <dagolden\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "Path-Tiny",
  "EXE_FILES" => [],
  "LICENSE" => "apache",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "Path::Tiny",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "Digest" => "1.03",
    "Digest::SHA" => "5.45",
    "Exporter" => "5.57",
    "Fcntl" => 0,
    "File::Copy" => 0,
    "File::Path" => "2.07",
    "File::Spec" => "3.40",
    "File::Temp" => "0.19",
    "File::stat" => 0,
    "constant" => 0,
    "if" => 0,
    "overload" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Basename" => 0,
    "File::Spec" => "3.40",
    "File::Spec::Functions" => 0,
    "File::Spec::Unix" => 0,
    "File::Temp" => "0.19",
    "Test::More" => "0.96",
    "lib" => 0,
    "open" => 0
  },
  "VERSION" => "0.062",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Cwd" => 0,
  "Digest" => "1.03",
  "Digest::SHA" => "5.45",
  "Exporter" => "5.57",
  "ExtUtils::MakeMaker" => "6.17",
  "Fcntl" => 0,
  "File::Basename" => 0,
  "File::Copy" => 0,
  "File::Path" => "2.07",
  "File::Spec" => "3.40",
  "File::Spec::Functions" => 0,
  "File::Spec::Unix" => 0,
  "File::Temp" => "0.19",
  "File::stat" => 0,
  "Test::More" => "0.96",
  "constant" => 0,
  "if" => 0,
  "lib" => 0,
  "open" => 0,
  "overload" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);


