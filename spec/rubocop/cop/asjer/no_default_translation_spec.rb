# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Asjer::NoDefaultTranslation, :config do
  let(:config) { RuboCop::Config.new }

  it 'registers an offense when using t with default option' do
    expect_offense(<<~RUBY)
      t('some.key', default: 'fallback text')
                    ^^^^^^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY
  end

  it 'registers an offense when using I18n.t with default option' do
    expect_offense(<<~RUBY)
      I18n.t('some.key', default: 'fallback')
                         ^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY
  end

  it 'registers an offense when using I18n.translate with default option' do
    expect_offense(<<~RUBY)
      I18n.translate('some.key', default: t('other.key'))
                                 ^^^^^^^^^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY
  end

  it 'registers an offense when default is used with other options' do
    expect_offense(<<~RUBY)
      t('some.key', scope: :admin, default: 'text', count: 1)
                                   ^^^^^^^^^^^^^^^ Asjer/NoDefaultTranslation: Define translations in locale files instead of using `default:`.
    RUBY
  end

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
