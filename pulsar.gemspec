# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pulsar/version'

Gem::Specification.new do |gem|
  gem.name           = 'pulsar'
  gem.version        = Pulsar::VERSION
  gem.authors        = ['Alberto Vena', 'Matteo Latini']
  gem.email          = ['info@nebulab.it']
  gem.homepage       = 'http://pulsar.nebulab.it'
  gem.description    = 'Manage your Capistrano deployments with ease'
  gem.summary        = '
    Pulsar helps with Capistrano configuration management. It uses a repository
    to store all your precious configurations and recipes to build Capistrano
    deploys on it.
  '

  gem.files          = `git ls-files`.split($/)
  gem.executables    = gem.files.grep(/^bin\//).map { |f| File.basename(f) }
  gem.test_files     = gem.files.grep(/^(test|spec|features)\//)
  gem.require_paths  = ['lib']

  gem.add_dependency 'clamp', '~> 0.5'
  gem.add_dependency 'bundler', '~> 1.2'
  gem.add_dependency 'colored', '~> 1.2'

  gem.add_development_dependency 'rake', '10.3.2'
  gem.add_development_dependency 'rspec', '3.1.0'
  gem.add_development_dependency 'codeclimate-test-reporter', '~> 0.4.6'
  gem.add_development_dependency 'rubocop', '~> 0.29.1'
end
