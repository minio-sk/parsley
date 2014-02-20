# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'parsley/version'

Gem::Specification.new do |gem|
  gem.name          = 'parsley'
  gem.version       = Parsley::VERSION
  gem.authors       = ['Tomas Kramar', 'Jan Suchal']
  gem.email         = ['kramar.tomas@gmail.com', 'johno@jsmf.net']
  gem.description   = gem.summary = %q{Web scraping infrastructure.}
  gem.homepage      = 'http://github.com/minio-sk/parsley'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.post_install_message = <<EOM
Parsley depends on bunch of command line utilities. Make sure that these
utilities are installed or some parts of the library will not work.

  gzip -- for unzipping
  unoconv -- for decoding RTF document to plain text
EOM

  gem.add_development_dependency('rspec', '~> 2.14.1')

  gem.add_dependency('nokogiri', '~> 1.6.0.rc1')
  gem.add_dependency('sidekiq', '~> 2.17.0')
end
