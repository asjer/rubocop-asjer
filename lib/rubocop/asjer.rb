# frozen_string_literal: true

require 'rubocop'

require_relative 'asjer/version'
require_relative 'asjer/plugin'
require_relative 'cop/asjer/no_default_translation'
require_relative 'cop/asjer/explicit_migration_version_in_spec'
require_relative 'cop/asjer/migration_schema_only'
require_relative 'cop/asjer/rails_class_order'
require_relative 'cop/asjer/system_spec_login_as'

module RuboCop
  module Asjer
    class Error < StandardError; end
  end
end
