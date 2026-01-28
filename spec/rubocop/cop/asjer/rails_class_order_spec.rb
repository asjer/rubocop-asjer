# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength
RSpec.describe RuboCop::Cop::Asjer::RailsClassOrder, :config do
  let(:config) { RuboCop::Config.new }
  let(:msg) do
    'Asjer/RailsClassOrder: Declarative methods should be sorted by type: scopes, attributes, ' \
      'enums, associations, validations, callbacks, then others.'
  end

  it 'registers an offense when associations come after callbacks' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_create :set_name
        ^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        belongs_to :role
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :role

        before_create :set_name
      end
    RUBY
  end

  it 'registers an offense when methods are out of order' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :plan
        ^^^^^^^^^^^^^^^^ #{msg}
        validate :validate_name
        after_create :after_create_1
        has_many :messages
        attr_readonly :email
        after_create :after_create_2
        belongs_to :role
        before_create :set_name
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        attr_readonly :email

        belongs_to :plan
        belongs_to :role
        has_many :messages

        validate :validate_name

        before_create :set_name
        after_create :after_create_1
        after_create :after_create_2
      end
    RUBY
  end

  it 'registers an offense when callbacks are out of order' do
    expect_offense(<<~RUBY)
      class Post < ApplicationRecord
        after_save :do_something
        ^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        before_save :do_first
      end
    RUBY

    expect_correction(<<~RUBY)
      class Post < ApplicationRecord
        before_save :do_first
        after_save :do_something
      end
    RUBY
  end

  it 'registers an offense when attributes come after callbacks' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :encrypt_email
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        attr_readonly :email
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        attr_readonly :email

        before_save :encrypt_email
      end
    RUBY
  end

  it 'does not register an offense when methods are in correct order' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(active: true) }

        attr_readonly :email

        belongs_to :plan
        belongs_to :role
        has_many :messages

        validate :validate_name

        before_create :set_name
        after_create :after_create_1
      end
    RUBY
  end

  it 'does not register an offense for a class with only associations' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :plan
        has_many :messages
      end
    RUBY
  end

  it 'does not register an offense for a class with only callbacks' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        before_save :do_first
        after_save :do_last
      end
    RUBY
  end

  it 'does not register an offense for an empty class' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
      end
    RUBY
  end

  it 'does not register an offense for a class with no declarative methods' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        def some_method
          :ok
        end
      end
    RUBY
  end

  it 'does not register an offense when non-declarative methods are between correctly ordered declarative methods' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        attr_readonly :email

        belongs_to :plan

        def some_method
          :ok
        end

        before_save :do_something
      end
    RUBY
  end

  it 'autocorrects when include statement is between declarative methods' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :do_something
        ^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}

        include Concerns::Trackable

        belongs_to :plan
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :plan

        before_save :do_something

        include Concerns::Trackable

      end
    RUBY
  end

  it 'autocorrects when constant definition is between declarative methods' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        after_create :notify
        ^^^^^^^^^^^^^^^^^^^^ #{msg}

        STATUSES = %w[active inactive].freeze

        belongs_to :organization
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :organization

        after_create :notify

        STATUSES = %w[active inactive].freeze

      end
    RUBY
  end

  it 'autocorrects when method definition is between declarative methods' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :do_something
        ^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}

        def some_method
          :ok
        end

        belongs_to :plan
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :plan

        before_save :do_something

        def some_method
          :ok
        end

      end
    RUBY
  end

  it 'preserves comments attached to declarative methods' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        # Send welcome email
        after_create :send_welcome
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        # Primary organization
        belongs_to :organization
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        # Primary organization
        belongs_to :organization

        # Send welcome email
        after_create :send_welcome
      end
    RUBY
  end

  it 'handles has_one and has_and_belongs_to_many' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :do_something
        ^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        has_one :profile
        has_and_belongs_to_many :roles
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        has_one :profile
        has_and_belongs_to_many :roles

        before_save :do_something
      end
    RUBY
  end

  it 'handles validates and validate correctly' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :do_something
        ^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        validates :name, presence: true
        validate :custom_validation
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        validates :name, presence: true
        validate :custom_validation

        before_save :do_something
      end
    RUBY
  end

  it 'handles serialize as attribute' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :role
        ^^^^^^^^^^^^^^^^ #{msg}
        serialize :preferences
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        serialize :preferences

        belongs_to :role
      end
    RUBY
  end

  it 'handles scopes first' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :role
        ^^^^^^^^^^^^^^^^ #{msg}
        scope :active, -> { where(active: true) }
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(active: true) }

        belongs_to :role
      end
    RUBY
  end

  it 'places scopes before associations and callbacks' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :do_something
        ^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        scope :active, -> { where(active: true) }
        belongs_to :role
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        scope :active, -> { where(active: true) }

        belongs_to :role

        before_save :do_something
      end
    RUBY
  end

  it 'handles default_scope before scope' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        default_scope { where(deleted: false) }
        scope :active, -> { where(active: true) }
      end
    RUBY
  end

  it 'handles enums between attributes and associations' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :role
        ^^^^^^^^^^^^^^^^ #{msg}
        enum :status, [:pending, :active]
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        enum :status, [:pending, :active]

        belongs_to :role
      end
    RUBY
  end

  it 'separates validations from callbacks' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        after_save :notify
        ^^^^^^^^^^^^^^^^^^ #{msg}
        validates :name, presence: true
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        validates :name, presence: true

        after_save :notify
      end
    RUBY
  end

  it 'handles Active Storage attachments' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        before_save :process_avatar
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
        has_one_attached :avatar
        has_many_attached :documents
      end
    RUBY

    expect_correction(<<~RUBY)
      class User < ApplicationRecord
        has_one_attached :avatar
        has_many_attached :documents

        before_save :process_avatar
      end
    RUBY
  end

  context 'with custom configuration' do
    let(:config) do
      RuboCop::Config.new(
        'Asjer/RailsClassOrder' => {
          'Associations' => %w[has_many belongs_to],
          'Callbacks' => %w[after_save before_save],
          'Others' => %w[serialize]
        }
      )
    end

    it 'respects custom association order' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          belongs_to :role
          ^^^^^^^^^^^^^^^^ Declarative methods should be sorted by type: scopes, attributes, enums, associations, validations, callbacks, then others.
          has_many :posts
        end
      RUBY

      expect_correction(<<~RUBY)
        class User < ApplicationRecord
          has_many :posts
          belongs_to :role
        end
      RUBY
    end

    it 'respects custom callback order' do
      expect_offense(<<~RUBY)
        class User < ApplicationRecord
          before_save :first
          ^^^^^^^^^^^^^^^^^^ Declarative methods should be sorted by type: scopes, attributes, enums, associations, validations, callbacks, then others.
          after_save :second
        end
      RUBY

      expect_correction(<<~RUBY)
        class User < ApplicationRecord
          after_save :second
          before_save :first
        end
      RUBY
    end
  end
end
# rubocop:enable RSpec/ExampleLength
