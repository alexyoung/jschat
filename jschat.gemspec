require 'rake'

Gem::Specification.new do |s|
  s.name = %q{jschat}
  s.version = '0.2.5'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Alex R. Young']
  s.date = %q{2010-03-21}
  s.description = %q{JsChat is a JSON-based web and console chat app.}
  s.email = %q{alex@alexyoung.org}
  s.files = FileList['{bin,http,lib,test}/**/*', 'README.textile', 'MIT-LICENSE'].to_a
  s.has_rdoc = false
  s.bindir = 'bin'
  s.executables = %w{jschat-server jschat-client jschat-web}
  s.default_executable = 'bin/jschat-server'
  s.homepage = %q{http://github.com/alexyoung/jschat}
  s.summary = %q{JsChat features a chat server, client and web app.}

  s.add_dependency('sinatra', '>= 0.9.4')
  s.add_dependency('json', '>= 1.1.9')
  s.add_dependency('sprockets', '>= 1.0.2')
  s.add_dependency('eventmachine', '>= 0.12.8')
  s.add_dependency('ncurses', '>= 0.9.1')
end
