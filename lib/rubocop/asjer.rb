# frozen_string_literal: true

require 'rubocop'

require_relative 'asjer/version'
require_relative 'asjer/inject'
require_relative 'cop/asjer/no_default_translation'

module RuboCop
  module Asjer
    class Error < StandardError; end
  end
end
