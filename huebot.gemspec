require_relative 'lib/huebot/version'

Gem::Specification.new do |s|
  s.name = 'huebot'
  s.version = Huebot::VERSION
  s.authors = ['Jordan Hollinger']
  s.email = 'jordan.hollinger@gmail.com'
  s.date = '2023-12-22'

  s.summary = 'Orchestration for Hue devices'
  s.description = 'Declare and run YAML programs for Philips Hue devices'
  s.homepage = 'https://github.com/jhollinger/huebot'
  s.licenses = ['MIT']
  s.required_ruby_version = '>= 2.1.0'

  s.files = [Dir.glob('lib/**/*'), 'README.md'].flatten
  s.require_paths = ['lib']
  s.executables << 'huebot'

  s.add_development_dependency 'minitest', '~> 5.0'
  s.add_development_dependency 'rake', '~> 13.0'
end
