# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module Asjer
    # A plugin that integrates RuboCop Asjer with RuboCop's plugin system.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: 'rubocop-asjer',
          version: VERSION,
          homepage: 'https://github.com/asjer/rubocop-asjer',
          description: 'A collection of custom RuboCop cops for personal use, including i18n best practices.'
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join('../../../config/default.yml')
        )
      end
    end
  end
end
