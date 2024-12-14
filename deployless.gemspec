lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'deployless/version'

Gem::Specification.new do |s|
  s.add_development_dependency "rspec", '~> 3.7', '>= 3.7.0'
  s.add_development_dependency 'pry'

  s.name        = 'deployless'
  s.version     = Deployless::Version
  s.date        = '2024-12-14'
  s.summary     = "Spend less time configuring deployment for your Rails application"
  s.description = "Spend less time configuring deployment for your Rails application"
  s.authors     = ["Paweł Dąbrowski"]
  s.email       = 'contact@paweldabrowski.com'
  s.files       = Dir['lib/**/*.rb', 'spec/helper.rb', 'bin/*']
  s.bindir      = 'bin'
  s.executables = ['dpls']
  s.homepage    = 'https://github.com/impactahead/deployless'
  s.license     = 'MIT'

  s.add_runtime_dependency 'sshkit', '1.23.2'
  s.add_runtime_dependency 'tty-option', '0.3.0'
  s.add_runtime_dependency 'tty-prompt', '0.23.1'
  s.add_runtime_dependency 'tty-file', '0.10.0'
end
