# frozen_string_literal: true

module RuboCop
  module Cop
    module Asjer
      # Requires system specs to use a helper that signs in and visits together.
      #
      # Warden's handoff applies to the next request reaching the app server,
      # which need not be the browser's intended visit. The application must
      # provide the replacement helper.
      #
      # @example
      #   # bad
      #   login_as(user)
      #   visit dashboard_path
      #
      #   # good
      #   sign_in_and_visit(user, dashboard_path)
      #
      class SystemSpecLoginAs < Base
        MSG = 'Use `%<helper>s` instead of `%<method>s` in system specs: ' \
              'the Warden handoff applies to whichever request reaches the app server next, ' \
              "not necessarily the browser's visit."

        def on_send(node)
          return unless node.receiver.nil?
          return unless cop_config.fetch('MethodNames', ['login_as']).include?(node.method_name.to_s)

          helper = cop_config.fetch('PreferredHelper', 'sign_in_and_visit')
          add_offense(node.loc.selector, message: format(MSG, helper: helper, method: node.method_name))
        end
      end
    end
  end
end
