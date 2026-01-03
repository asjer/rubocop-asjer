# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Asjer::NoDefaultTranslation, :config do
  let(:config) { RuboCop::Config.new }

  # rubocop:disable RSpec/ExampleLength
  it 'registers an offense and autocorrects when using t with default option' do
    expect_offense(<<~RUBY)
      t('some.key', default: 'fallback text')
                    ^^^^^^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY

    expect_correction(<<~RUBY)
      t('some.key')
    RUBY
  end

  it 'registers an offense and autocorrects when using I18n.t with default option' do
    expect_offense(<<~RUBY)
      I18n.t('some.key', default: 'fallback')
                         ^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY

    expect_correction(<<~RUBY)
      I18n.t('some.key')
    RUBY
  end

  it 'registers an offense and autocorrects when using I18n.translate with default option' do
    expect_offense(<<~RUBY)
      I18n.translate('some.key', default: t('other.key'))
                                 ^^^^^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY

    expect_correction(<<~RUBY)
      I18n.translate('some.key')
    RUBY
  end

  it 'registers an offense and autocorrects when default is used with other options' do
    expect_offense(<<~RUBY)
      t('some.key', scope: :admin, default: 'text', count: 1)
                                   ^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY

    expect_correction(<<~RUBY)
      t('some.key', scope: :admin, count: 1)
    RUBY
  end

  it 'autocorrects when default is the first option among multiple' do
    expect_offense(<<~RUBY)
      t('some.key', default: 'text', scope: :admin)
                    ^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY

    expect_correction(<<~RUBY)
      t('some.key', scope: :admin)
    RUBY
  end

  it 'autocorrects I18n.t with multiple options' do
    expect_offense(<<~RUBY)
      I18n.t('some.key', scope: :foo, default: 'fallback')
                                      ^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY

    expect_correction(<<~RUBY)
      I18n.t('some.key', scope: :foo)
    RUBY
  end
  # rubocop:enable RSpec/ExampleLength

  it 'does not register an offense when using t without default' do
    expect_no_offenses(<<~RUBY)
      t('some.key')
    RUBY
  end

  it 'does not register an offense when using I18n.t without default' do
    expect_no_offenses(<<~RUBY)
      I18n.t('some.key')
    RUBY
  end

  it 'does not register an offense when using t with other options but no default' do
    expect_no_offenses(<<~RUBY)
      t('some.key', scope: :admin, count: 1)
    RUBY
  end

  it 'does not register an offense for unrelated method calls' do
    expect_no_offenses(<<~RUBY)
      some_method('key', default: 'value')
    RUBY
  end
end
