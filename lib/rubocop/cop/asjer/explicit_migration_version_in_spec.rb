# frozen_string_literal: true

module RuboCop
  module Cop
    module Asjer
      # Requires migration specs to run migrations to an explicit version.
      #
      # `rollback`, `forward` and `migrate` without a version (or with `nil`) move relative to
      # the latest migration, so the spec breaks as soon as anyone adds an
      # unrelated migration. Name the version the spec is about instead.
      #
      # @example
      #   # bad
      #   connection.pool.migration_context.rollback(1)
      #   migration_context.forward
      #   migration_context.migrate
      #
      #   # good
      #   connection.pool.migration_context.run(:down, 20261012170000)
      #   migration_context.migrate(20261012170000)
      #
      class ExplicitMigrationVersionInSpec < Base
        MSG = 'Run migrations to an explicit version, e.g. `migration_context.run(:down, VERSION)`; ' \
              '`%<name>s` depends on the latest migration.'

        RESTRICT_ON_SEND = %i[rollback forward migrate].freeze

        def on_send(node)
          return if node.method?(:migrate) && node.arguments? && !node.first_argument.nil_type?

          add_offense(node.loc.selector, message: format(MSG, name: node.method_name))
        end
        alias on_csend on_send
      end
    end
  end
end
