# frozen_string_literal: true

require 'rubocop'

require_relative 'asjer/version'
require_relative 'asjer/plugin'
require_relative 'cop/asjer/no_default_translation'
require_relative 'cop/asjer/rails_class_order'

module RuboCop
  module Asjer
    class Error < StandardError; end
  end
end
