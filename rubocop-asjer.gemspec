# frozen_string_literal: true

require_relative 'lib/rubocop/asjer/version'

Gem::Specification.new do |spec|
  spec.name = 'rubocop-asjer'
  spec.version = RuboCop::Asjer::VERSION
  spec.authors = ['Asjer Querido']
  spec.email = ['mail@asjer.io']

  spec.summary = 'Custom RuboCop cops by Asjer'
  spec.description = 'A collection of custom RuboCop cops for personal use, including i18n best practices.'
  spec.homepage = 'https://github.com/asjer/rubocop-asjer'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/asjer/rubocop-asjer'
  spec.metadata['changelog_uri'] = 'https://github.com/asjer/rubocop-asjer/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['default_lint_roller_plugin'] = 'RuboCop::Asjer::Plugin'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'lint_roller', '~> 1.1'
  spec.add_dependency 'rubocop', '>= 1.72.0'
end
