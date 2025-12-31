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
        MSG = 'Define translations in locale files instead of using `default:`.'

        RESTRICT_ON_SEND = %i[t translate].freeze

        # @!method translation_with_default?(node)
        def_node_matcher :translation_with_default?, <<~PATTERN
          (send {nil? (const {nil? cbase} :I18n)} {:t :translate} ... (hash <$(pair (sym :default) _) ...>))
        PATTERN

        def on_send(node)
          translation_with_default?(node) do |default_pair|
            add_offense(default_pair)
          end
        end
      end
    end
  end
end
