# frozen_string_literal: true

module RuboCop
  module Cop
    module Asjer
      # Checks for translation calls that use the `default:` option.
      #
      # Using `default:` bypasses the locale system and can lead to
      # inconsistencies. Define all translations in the locale files instead.
      #
      # @example
      #   # bad
      #   t('some.key', default: 'fallback text')
      #   I18n.t('some.key', default: 'fallback')
      #   I18n.translate('some.key', default: t('other.key'))
      #
      #   # good
      #   t('some.key')
      #   I18n.t('some.key')
      #
      class NoDefaultTranslation < Base
        extend AutoCorrector
        include RangeHelp

        MSG = 'Define translations in locale files instead of using `default:`.'

        RESTRICT_ON_SEND = %i[t translate].freeze

        # @!method translation_with_default?(node)
        def_node_matcher :translation_with_default?, <<~PATTERN
          (send {nil? (const {nil? cbase} :I18n)} {:t :translate} ... (hash <$(pair (sym :default) _) ...>))
        PATTERN

        def on_send(node)
          translation_with_default?(node) do |default_pair|
            add_offense(default_pair) do |corrector|
              corrector.remove(removal_range(default_pair))
            end
          end
        end

        private

        def removal_range(node)
          hash_node = node.parent
          pairs = hash_node.pairs

          return hash_with_comma_range(hash_node) if pairs.size == 1

          pair_removal_range(node, pairs)
        end

        def hash_with_comma_range(hash_node)
          # Remove the comma before the hash and the hash itself
          range_between(hash_node.source_range.begin_pos - 2, hash_node.source_range.end_pos)
        end

        def pair_removal_range(node, pairs)
          index = pairs.index(node)

          last_pair?(index, pairs) ? leading_range(node, pairs[index - 1]) : trailing_range(node, pairs[index + 1])
        end

        def last_pair?(index, pairs)
          index == pairs.size - 1
        end

        def leading_range(node, prev_pair)
          range_between(prev_pair.source_range.end_pos, node.source_range.end_pos)
        end

        def trailing_range(node, next_pair)
          range_between(node.source_range.begin_pos, next_pair.source_range.begin_pos)
        end
      end
    end
  end
end
