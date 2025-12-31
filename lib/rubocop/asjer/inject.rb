# frozen_string_literal: true

require 'yaml'

module RuboCop
  module Asjer
    # Injects the default configuration into RuboCop
    class Inject
      def self.defaults!
        path = File.expand_path('../../../config/default.yml', __dir__)
        hash = YAML.safe_load_file(path)
        config = RuboCop::Config.new(hash, path)
        config = RuboCop::ConfigLoader.merge_with_default(config, path)
        RuboCop::ConfigLoader.instance_variable_set(:@default_configuration, config)
      end
    end
  end
end

RuboCop::Asjer::Inject.defaults!
