# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Asjer::SystemSpecLoginAs, :config do
  let(:system_spec) { 'spec/system/authentication_spec.rb' }
  let(:msg) do
    'Use `%<helper>s` instead of `%<method>s` in system specs: ' \
      'the Warden handoff applies to whichever request reaches the app server next, ' \
      "not necessarily the browser's visit."
  end

  it 'registers an offense for login_as followed by a visit' do
    expect_offense(<<~RUBY, system_spec)
      login_as(user)
      ^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'login_as')}
      visit dashboard_path
    RUBY

    expect_no_corrections
  end

  it 'registers an offense without any visit' do
    expect_offense(<<~RUBY, system_spec)
      login_as user, scope: :user
      ^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'login_as')}
    RUBY
  end

  it 'registers an offense in a before block' do
    expect_offense(<<~RUBY, system_spec)
      before do
        login_as(user)
        ^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'login_as')}
      end
    RUBY
  end

  it 'registers an offense for a multiline call' do
    expect_offense(<<~RUBY, system_spec)
      login_as(
      ^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'login_as')}
        user,
        scope: :user
      )
    RUBY
  end

  it 'registers every unqualified call, regardless of intervening statements' do
    expect_offense(<<~RUBY, system_spec)
      login_as(user)
      ^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'login_as')}
      perform_other_request
      login_as(other_user)
      ^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'login_as')}
      visit dashboard_path
    RUBY
  end

  it 'accepts the preferred helper and calls with an explicit receiver' do
    expect_no_offenses(<<~RUBY, system_spec)
      sign_in_and_visit(user, dashboard_path)
      foo.login_as(user)
      self.login_as(user)
      foo&.login_as(user)
    RUBY
  end

  describe 'PreferredHelper' do
    let(:cop_config) { { 'PreferredHelper' => 'authenticate_and_visit' } }

    it 'names the configured replacement helper in the offense' do
      expect_offense(<<~RUBY, system_spec)
        login_as(user)
        ^^^^^^^^ #{format(msg, helper: 'authenticate_and_visit', method: 'login_as')}
      RUBY
    end
  end

  describe 'MethodNames' do
    let(:cop_config) { { 'MethodNames' => %w[sign_in_as authenticate_as] } }

    it 'checks the configured method names instead of login_as' do
      expect_offense(<<~RUBY, system_spec)
        sign_in_as(user)
        ^^^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'sign_in_as')}
        authenticate_as(user)
        ^^^^^^^^^^^^^^^ #{format(msg, helper: 'sign_in_and_visit', method: 'authenticate_as')}
        login_as(user)
        foo.sign_in_as(user)
      RUBY
    end
  end
end
