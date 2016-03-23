# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "notification-dispatch/version"

Gem::Specification.new do |s|
  s.name        = "notification-dispatch"
  s.version     = Notification::Dispatch::VERSION
  s.authors     = ["Kyle Campos"]
  s.email       = ["kyle.campos@gmail.com"]
  s.homepage    = %q{https://github.com/BioIQ/notification-dispatch}
  s.summary     = %q{Notification dispatcher to collection of services}
  s.description = %q{Notification dispatcher to collection of services}

  s.rubyforge_project = "notification-dispatch"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
  s.add_development_dependency "keen"

  s.add_runtime_dependency "dogapi"
  s.add_runtime_dependency "keen"
end
