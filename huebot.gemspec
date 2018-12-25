require_relative 'lib/huebot/version'

Gem::Specification.new do |s|
  s.name = 'huebot'
  s.version = Huebot::VERSION
  s.licenses = ['MIT']
  s.summary = 'Orchestration for Hue devices'
  s.description = 'Declare and run YAML programs for Philips Hue devices'
  s.date = '2018-12-24'
  s.authors = ['Jordan Hollinger']
  s.email = 'jordan.hollinger@gmail.com'
  s.homepage = 'https://github.com/jhollinger/huebot'
  s.require_paths = ['lib']
  s.files = [Dir.glob('lib/**/*'), 'README.md'].flatten
  s.executables << 'huebot'
  s.required_ruby_version = '>= 2.1.0'
  s.add_runtime_dependency 'hue', '~> 0.2.0'
end
