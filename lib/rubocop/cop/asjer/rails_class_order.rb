# frozen_string_literal: true

module RuboCop
  module Cop
    module Asjer
      # Enforces consistent ordering of declarative methods in Rails models.
      #
      # Methods are grouped into three categories: associations, callbacks,
      # and others. Within each category, methods are sorted by their position
      # in the configured list. Groups are separated by blank lines.
      #
      # The order is: associations, then callbacks, then others.
      #
      # @example
      #   # bad
      #   class User < ApplicationRecord
      #     belongs_to :plan
      #     validate :validate_name
      #     after_create :after_create_1
      #     has_many :messages
      #     attr_readonly :email
      #     after_create :after_create_2
      #     belongs_to :role
      #     before_create :set_name
      #   end
      #
      #   # good
      #   class User < ApplicationRecord
      #     belongs_to :plan
      #     belongs_to :role
      #     has_many :messages
      #
      #     validate :validate_name
      #     before_create :set_name
      #     after_create :after_create_1
      #     after_create :after_create_2
      #
      #     attr_readonly :email
      #   end
      #
      # Default method lists for RailsClassOrder cop
      module RailsClassOrderDefaults
        ASSOCIATIONS = %w[
          belongs_to has_many has_one has_and_belongs_to_many
        ].freeze

        CALLBACKS = %w[
          after_initialize after_find after_touch
          before_validation validates validate after_validation
          before_save around_save before_create around_create
          before_update around_update before_destroy around_destroy
          after_destroy after_update after_create after_save
          after_commit after_rollback
        ].freeze

        OTHERS = %w[attr_readonly serialize].freeze
      end

      # Enforces consistent ordering of declarative methods in Rails models.
      #
      # @see RailsClassOrderDefaults for default method lists
      class RailsClassOrder < Base
        extend AutoCorrector
        include RangeHelp

        MSG = 'Declarative methods should be sorted by type: associations, callbacks, then others.'

        TYPE_ORDER = { association: 0, callback: 1, other: 2 }.freeze

        def on_class(node)
          _name, _superclass, body = *node
          return unless body&.begin_type?

          targets = target_methods(body)
          return if targets.empty?

          sorted = sort_methods(targets)
          return if targets == sorted

          add_offense(body) do |corrector|
            autocorrect(corrector, body, targets, sorted)
          end
        end

        private

        def associations
          @associations ||= cop_config.fetch('Associations', RailsClassOrderDefaults::ASSOCIATIONS).map(&:to_sym)
        end

        def callbacks
          @callbacks ||= cop_config.fetch('Callbacks', RailsClassOrderDefaults::CALLBACKS).map(&:to_sym)
        end

        def others
          @others ||= cop_config.fetch('Others', RailsClassOrderDefaults::OTHERS).map(&:to_sym)
        end

        def all_target_methods
          @all_target_methods ||= associations + callbacks + others
        end

        def target_methods(body)
          body.children.select do |child|
            child.send_type? && all_target_methods.include?(child.method_name)
          end
        end

        def sort_methods(methods)
          # Use sort_by with index to make stable sort (preserve original order for equal elements)
          methods.each_with_index.sort_by do |method, index|
            [
              method_type_order(method),
              method_position_in_type(method),
              index
            ]
          end.map(&:first)
        end

        def method_type(method)
          name = method.method_name
          return :association if associations.include?(name)
          return :callback if callbacks.include?(name)

          :other
        end

        def method_type_order(method)
          TYPE_ORDER[method_type(method)]
        end

        def method_position_in_type(method)
          name = method.method_name
          list = method_list_for_type(method_type(method))
          list.index(name) || list.size
        end

        def method_list_for_type(type)
          { association: associations, callback: callbacks, other: others }[type]
        end

        def autocorrect(corrector, _body, original, sorted)
          grouped = group_by_type(sorted)
          new_source = build_grouped_source(grouped, original)
          range = methods_range(original)
          corrector.replace(range, new_source)
        end

        def group_by_type(methods)
          methods.group_by { |m| method_type(m) }
        end

        def build_grouped_source(grouped, original)
          indent = ' ' * original.first.loc.column

          groups = []
          %i[association callback other].each do |type|
            next unless grouped[type]&.any?

            group_lines = grouped[type].map(&:source)
            groups << group_lines.join("\n#{indent}")
          end

          groups.join("\n\n#{indent}")
        end

        def methods_range(methods)
          first = methods.min_by { |m| m.loc.expression.begin_pos }
          last = methods.max_by { |m| m.loc.expression.end_pos }

          range_between(first.loc.expression.begin_pos, last.loc.expression.end_pos)
        end
      end
    end
  end
end
