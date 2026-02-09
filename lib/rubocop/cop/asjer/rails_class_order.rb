# frozen_string_literal: true

module RuboCop
  module Cop
    module Asjer
      # Enforces consistent ordering of declarative methods in Rails models.
      #
      # Methods are grouped into seven categories following Rails Style Guide:
      # scopes, attributes, enums, associations, validations, callbacks, and others.
      # Within each category, methods are sorted by their position in the configured list.
      # Groups are separated by blank lines.
      #
      # The order is: scopes, attributes, enums, associations, validations, callbacks, then others.
      #
      # @example
      #   # bad
      #   class User < ApplicationRecord
      #     belongs_to :plan
      #     validate :validate_name
      #     after_create :after_create_1
      #     has_many :messages
      #     scope :active, -> { where(active: true) }
      #     attr_readonly :email
      #     enum :status, [:pending, :active]
      #     after_create :after_create_2
      #     belongs_to :role
      #     before_create :set_name
      #   end
      #
      #   # good
      #   class User < ApplicationRecord
      #     scope :active, -> { where(active: true) }
      #
      #     attr_readonly :email
      #
      #     enum :status, [:pending, :active]
      #
      #     belongs_to :plan
      #     belongs_to :role
      #     has_many :messages
      #
      #     validate :validate_name
      #
      #     before_create :set_name
      #     after_create :after_create_1
      #     after_create :after_create_2
      #   end
      #
      # Default method lists for RailsClassOrder cop
      module RailsClassOrderDefaults
        SCOPES = %w[default_scope scope].freeze

        ATTRIBUTES = %w[
          attr_accessor attr_reader attr_writer attr_readonly
          attribute serialize store store_accessor
        ].freeze

        ENUMS = %w[enum].freeze

        ASSOCIATIONS = %w[
          belongs_to has_one has_many has_and_belongs_to_many
          has_one_attached has_many_attached
        ].freeze

        VALIDATIONS = %w[
          validates validates_acceptance_of validates_associated
          validates_comparison_of validates_confirmation_of validates_each
          validates_exclusion_of validates_format_of validates_inclusion_of
          validates_length_of validates_size_of validates_numericality_of
          validates_presence_of validates_uniqueness_of validates_with
          validate
        ].freeze

        CALLBACKS = %w[
          after_initialize after_find after_touch
          before_validation after_validation
          before_save around_save
          before_create around_create after_create
          before_update around_update after_update
          after_save
          before_destroy around_destroy after_destroy
          before_commit after_commit after_rollback
          after_save_commit after_create_commit after_update_commit after_destroy_commit
        ].freeze

        OTHERS = %w[
          encrypts normalizes delegate delegate_missing_to
          accepts_nested_attributes_for has_secure_password
          has_secure_token generates_token_for composed_of
        ].freeze
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

          range_between(line_start, skip_trailing_blank_lines(source, end_pos))
        end

        def skip_trailing_blank_lines(source, pos)
          while pos < source.length
            line_end = source.index("\n", pos)
            break unless line_end
            break unless source[pos...line_end].strip.empty?

            pos = line_end + 1
          end
          pos
        end

        def build_sorted_source(sorted, original)
          indent = ' ' * original.first.loc.column
          grouped = sorted.group_by { |m| method_type(m) }
          format_grouped_source(grouped, indent)
        end

        def format_grouped_source(grouped, indent)
          self.class::TYPE_ORDER.keys.filter_map do |type|
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

        MSG = 'Declarative methods should be sorted by type: scopes, attributes, enums, ' \
              'associations, validations, callbacks, then others.'

        TYPE_ORDER = {
          scope: 0,
          attribute: 1,
          enum: 2,
          association: 3,
          validation: 4,
          callback: 5,
          other: 6
        }.freeze

        CATEGORY_CONFIG = {
          scope: { key: 'Scopes', const: :SCOPES },
          attribute: { key: 'Attributes', const: :ATTRIBUTES },
          enum: { key: 'Enums', const: :ENUMS },
          association: { key: 'Associations', const: :ASSOCIATIONS },
          validation: { key: 'Validations', const: :VALIDATIONS },
          callback: { key: 'Callbacks', const: :CALLBACKS },
          other: { key: 'Others', const: :OTHERS }
        }.freeze

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

        def category_methods(category)
          cfg = CATEGORY_CONFIG[category]
          instance_variable_get(:"@#{category}") ||
            instance_variable_set(
              :"@#{category}",
              cop_config.fetch(cfg[:key], RailsClassOrderDefaults.const_get(cfg[:const])).map(&:to_sym)
            )
        end

        def all_target_methods
          @all_target_methods ||= TYPE_ORDER.keys.flat_map { |cat| category_methods(cat) }
        end

        def target_methods(body)
          body.children.select { |child| child.send_type? && all_target_methods.include?(child.method_name) }
        end

        def sort_methods(methods)
          methods.each_with_index.sort_by do |method, index|
            [method_type_order(method), method_position_in_type(method), index]
          end.map(&:first)
        end

        def method_type(method)
          name = method.method_name
          TYPE_ORDER.each_key do |category|
            return category if category_methods(category).include?(name)
          end
          :other
        end

        def method_type_order(method)
          TYPE_ORDER[method_type(method)]
        end

        def method_position_in_type(method)
          list = category_methods(method_type(method))
          list.index(method.method_name) || list.size
        end
      end
    end
  end
end
