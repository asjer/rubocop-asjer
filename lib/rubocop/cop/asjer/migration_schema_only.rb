# frozen_string_literal: true

module RuboCop
  module Cop
    module Asjer
      # Default lists for MigrationSchemaOnly.
      module MigrationSchemaOnlyDefaults
        ALLOWED_METHODS = %w[
          create_table create_join_table change_table rename_table drop_table drop_join_table
          add_column remove_column remove_columns rename_column change_column
          change_column_default change_column_null change_column_comment change_table_comment
          add_timestamps remove_timestamps
          add_index remove_index rename_index
          add_reference remove_reference add_belongs_to remove_belongs_to
          add_foreign_key remove_foreign_key
          add_check_constraint remove_check_constraint validate_check_constraint
          validate_foreign_key validate_constraint
          add_exclusion_constraint remove_exclusion_constraint
          add_unique_constraint remove_unique_constraint
          enable_extension disable_extension
          create_enum drop_enum rename_enum add_enum_value rename_enum_value
          create_schema drop_schema
          create_virtual_table drop_virtual_table
          table_exists? column_exists? index_exists? index_name_exists?
          foreign_key_exists? check_constraint_exists? extension_enabled? view_exists?
          reversible revert up_only
          say say_with_time suppress_messages
          disable_ddl_transaction!
          raise private
        ].freeze

        ALLOWED_CONSTANTS = %w[ActiveRecord::IrreversibleMigration Rails].freeze

        # Calls that run code chosen at runtime; only block variables such as `t` may receive them.
        DYNAMIC_CALLS = %i[
          send public_send __send__ eval instance_eval instance_exec class_eval class_exec module_eval module_exec
        ].freeze
      end

      # Allows only schema statements in Rails migrations.
      #
      # Migrations change the schema. Raw SQL, model calls and other data
      # changes skip validations and callbacks, are often irreversible, and
      # belong in a maintenance task. This cop uses an allowlist: inside a
      # migration class, implicit-receiver calls must be schema statements
      # (`AllowedMethods`) or methods the migration defines itself, and only
      # `AllowedConstants` and constants the migration defines may be
      # referenced. Calls on block variables such as `t.string` and
      # `direction.up` are fine. Anything else, including `execute`,
      # `connection`, `send` and model constants, is an offense, so new
      # raw-SQL routes are rejected without updating a denylist.
      #
      # Check constraints and expression indexes stay allowed: they keep the
      # database consistent alongside model validations. `change_column` with
      # `using:` is rejected because it is always a SQL cast.
      #
      # Set `StartAfter` to the version of the last existing migration to
      # check only new migrations.
      #
      # @example
      #   # bad
      #   execute "UPDATE bookings SET source = 'web'"
      #   select_value('SELECT 1')
      #   connection.exec_query('SELECT 1')
      #   Booking.where(source: nil).update_all(source: 'web')
      #   add_index :bookings, Arel.sql('lower(code)')
      #   change_column :bookings, :date, :date, using: 'date::date'
      #
      #   # good
      #   create_table :examples do |t|
      #     t.string :status, null: false
      #   end
      #   add_index :examples, 'lower(status)'
      #   add_check_constraint :examples, "status IN ('open', 'closed')", name: :examples_status
      #
      class MigrationSchemaOnly < Base
        include MigrationSchemaOnlyDefaults

        CALL_MSG = 'Use only schema statements in migrations; move `%<name>s` and other data changes ' \
                   'or raw SQL to a maintenance task.'
        CONSTANT_MSG = 'Do not use `%<name>s` in migrations; move data changes and raw SQL to a maintenance task.'
        CAST_MSG = '`change_column` with `using:` runs a SQL cast; add a new column and copy the data ' \
                   'in a maintenance task.'
        OPTIONS_MSG = 'Write out the `change_column` options so `using:` SQL casts can be checked.'

        # @!method migration_class?(node)
        def_node_matcher :migration_class?, <<~PATTERN
          (class _ {
            (send (const (const {nil? cbase} :ActiveRecord) :Migration) :[] ...)
            (const (const {nil? cbase} :ActiveRecord) :Migration)
            (const (const (const {nil? cbase} :ActiveRecord) :Migration) :Current)
          } _)
        PATTERN

        def on_class(node)
          return unless migration_class?(node) && node.body && checked_file?

          @defined_methods = node.body.each_node(:def, :defs).map(&:method_name)
          @defined_constants = node.body.each_node(:casgn).filter_map { |casgn| casgn.name.to_s unless casgn.namespace }
          node.body.each_node(:send, :csend, :const) { |child| check(child) }
        end

        private

        def checked_file?
          start_after = cop_config['StartAfter']
          version = File.basename(processed_source.file_path.to_s)[/\A\d+/]
          start_after.nil? || version.nil? || version.to_i > start_after.to_i
        end

        def check(node)
          node.const_type? ? check_constant(node) : check_call(node)
        end

        def check_call(node)
          if disallowed_call?(node)
            add_offense(node, message: format(CALL_MSG, name: node.method_name))
          elsif node.method?(:change_column)
            check_cast(node)
          end
        end

        def disallowed_call?(node)
          receiver = node.receiver
          if receiver.nil? || receiver.self_type?
            !allowed_call?(node.method_name)
          elsif DYNAMIC_CALLS.include?(node.method_name)
            !receiver.lvar_type?
          else
            receiver.variable? && !receiver.lvar_type?
          end
        end

        def allowed_call?(name)
          allowed_methods.include?(name.to_s) || @defined_methods.include?(name)
        end

        def check_cast(node)
          node.arguments.each do |argument|
            argument.each_node(:pair, :kwsplat) do |option|
              if option.kwsplat_type?
                add_offense(option, message: OPTIONS_MSG) unless option.children.first.hash_type?
              elsif option.key.sym_type? && option.key.value == :using
                add_offense(option, message: CAST_MSG)
              end
            end
          end
        end

        def check_constant(node)
          return if namespace?(node) || reverted_migration?(node) || allowed_constant?(node.source)

          add_offense(node, message: format(CONSTANT_MSG, name: node.source))
        end

        # The `ActiveRecord` in `ActiveRecord::Base`; the full constant is checked instead.
        def namespace?(node)
          node.parent&.const_type? && node.parent.namespace.equal?(node)
        end

        def reverted_migration?(node)
          node.parent&.send_type? && node.parent.method?(:revert)
        end

        def allowed_constant?(name)
          allowed_constants.include?(name.delete_prefix('::')) || @defined_constants.include?(name)
        end

        def allowed_methods
          cop_config.fetch('AllowedMethods', ALLOWED_METHODS)
        end

        def allowed_constants
          cop_config.fetch('AllowedConstants', ALLOWED_CONSTANTS)
        end
      end
    end
  end
end
