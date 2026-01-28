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

      # Autocorrect helpers for RailsClassOrder cop
      module RailsClassOrderCorrector
        def autocorrect(corrector, body, original, sorted)
          first_target = original.min_by { |m| body.children.index(m) }
          new_source = build_sorted_source(sorted, original)
          corrector.replace(range_with_comments(first_target), new_source.rstrip)

          (original - [first_target]).each do |method|
            corrector.remove(full_method_range(method))
          end
        end

        def range_with_comments(node)
          comments = preceding_comments(node)
          start_pos = comments.empty? ? node.loc.expression.begin_pos : comments.first.loc.expression.begin_pos
          range_between(start_pos, node.loc.expression.end_pos)
        end

        def preceding_comments(node)
          collect_adjacent_comments(node.loc.expression)
        end

        def collect_adjacent_comments(node_pos)
          expected_line = node_pos.first_line - 1
          comments_before_node(node_pos).take_while do |comment|
            pos = comment.loc.expression
            (pos.last_line == expected_line).tap { expected_line = pos.first_line - 1 }
          end.reverse
        end

        def comments_before_node(node_pos)
          processed_source.comments.select { |c| c.loc.expression.end_pos < node_pos.begin_pos }.reverse
        end

        def full_method_range(node)
          range = range_with_comments(node)
          source = processed_source.buffer.source
          line_start = source.rindex("\n", range.begin_pos - 1)&.+(1) || 0
          end_pos = source[range.end_pos] == "\n" ? range.end_pos + 1 : range.end_pos
          range_between(line_start, end_pos)
        end

        def build_sorted_source(sorted, original)
          indent = ' ' * original.first.loc.column
          grouped = sorted.group_by { |m| method_type(m) }

          %i[association callback other].filter_map do |type|
            next unless grouped[type]&.any?

            grouped[type].map { |m| source_with_comments(m) }.join("\n#{indent}")
          end.join("\n\n#{indent}")
        end

        def source_with_comments(node)
          range = range_with_comments(node)
          processed_source.buffer.source[range.begin_pos...range.end_pos].lstrip
        end
      end

      # Enforces consistent ordering of declarative methods in Rails models.
      #
      # @see RailsClassOrderDefaults for default method lists
      class RailsClassOrder < Base
        extend AutoCorrector
        include RangeHelp
        include RailsClassOrderCorrector

        MSG = 'Declarative methods should be sorted by type: associations, callbacks, then others.'
        TYPE_ORDER = { association: 0, callback: 1, other: 2 }.freeze

        def on_class(node)
          _name, _superclass, body = *node
          return unless body&.begin_type?

          check_order(body)
        end

        private

        def check_order(body)
          targets = target_methods(body)
          return if targets.empty?

          sorted = sort_methods(targets)
          return if targets == sorted

          first_misplaced = targets.zip(sorted).find { |a, e| a != e }&.first
          add_offense(first_misplaced) { |corrector| autocorrect(corrector, body, targets, sorted) }
        end

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
          body.children.select { |child| child.send_type? && all_target_methods.include?(child.method_name) }
        end

        def sort_methods(methods)
          methods.each_with_index.sort_by { |m, i| [method_type_order(m), method_position_in_type(m), i] }.map(&:first)
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
          method_list_for_type(method_type(method)).index(method.method_name) || 999
        end

        def method_list_for_type(type)
          { association: associations, callback: callbacks, other: others }[type]
        end
      end
    end
  end
end
