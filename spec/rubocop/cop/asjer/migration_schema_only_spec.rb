# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Asjer::MigrationSchemaOnly, :config do
  let(:config) { RuboCop::Config.new }
  let(:migration_file) { 'db/migrate/20261014120000_example.rb' }

  def call_msg
    'Asjer/MigrationSchemaOnly: Use only schema statements in migrations; move `%<name>s` and other data changes ' \
      'or raw SQL to a maintenance task.'
  end

  def constant_msg
    'Asjer/MigrationSchemaOnly: Do not use `%<name>s` in migrations; ' \
      'move data changes and raw SQL to a maintenance task.'
  end

  def cast_msg
    'Asjer/MigrationSchemaOnly: `change_column` with `using:` runs a SQL cast; add a new column and copy the data ' \
      'in a maintenance task.'
  end

  def options_msg
    'Asjer/MigrationSchemaOnly: Write out the `change_column` options so `using:` SQL casts can be checked.'
  end

  def self_msg
    'Asjer/MigrationSchemaOnly: Call schema statements on `self` directly; ' \
      'passing `self` around hides calls from this check.'
  end

  def null_msg
    'Asjer/MigrationSchemaOnly: The `change_column_null` replacement value updates existing rows; ' \
      'backfill them in a maintenance task first.'
  end

  # A custom configuration does not display cop names.
  def unprefixed(message)
    message.delete_prefix('Asjer/MigrationSchemaOnly: ')
  end

  describe 'raw SQL and data changes' do
    it 'registers an offense for execute' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            execute "UPDATE bookings SET source = 'web'"
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
          end
        end
      RUBY
    end

    it 'registers an offense for SQL helpers that a denylist would miss' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            select_value('SELECT 1')
            ^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'select_value')}
            exec_insert_all('INSERT INTO bookings DEFAULT VALUES', nil)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'exec_insert_all')}
            self.execute('SELECT 1')
            ^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
          end
        end
      RUBY
    end

    it 'registers an offense for the connection and anything called on it' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            connection.execute_batch(['SELECT 1'])
            ^^^^^^^^^^ #{format(call_msg, name: 'connection')}
            connection.raw_connection.exec_params('UPDATE bookings SET source = $1', ['web'])
            ^^^^^^^^^^ #{format(call_msg, name: 'connection')}
          end
        end
      RUBY
    end

    it 'registers an offense for reflective and dynamic calls' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            send(:execute, 'SELECT 1')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'send')}
            public_send(:execute, 'SELECT 1')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'public_send')}
            eval("execute 'SELECT 1'")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'eval')}
          end
        end
      RUBY
    end

    it 'registers an offense for reflective and dynamic calls on any receiver except block variables' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            ''.itself.send(:eval, 'SELECT 1')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'send')}
            [].instance_eval { execute 'SELECT 1' }
            ^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'instance_eval')}
                               ^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
            target = ''
            target.instance_eval("ActiveRecord::Base.connection.execute('DELETE FROM bookings')")
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'instance_eval')}
            create_table :examples do |t|
              t.public_send :string, :status
            end
          end
        end
      RUBY
    end

    it 'registers an offense for passing self around, which would hide calls behind a local' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            migration = self
                        ^^^^ #{self_msg}
            migration.execute('DELETE FROM bookings')
          end
        end
      RUBY
    end

    it 'registers an offense for the NULL replacement of change_column_null, which updates rows' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            change_column_null :bookings, :source, false, 'web'
                                                          ^^^^^ #{null_msg}
            change_column_null :bookings, :source, false
            change_column_null :bookings, :source, false, nil
            change_table :bookings do |t|
              t.change_null :source, false, 'web'
                                            ^^^^^ #{null_msg}
              t.change_null :source, false
            end
          end
        end
      RUBY
    end

    it 'registers an offense for models, Arel and other constants' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            Booking.where(source: nil).update_all(source: 'web')
            ^^^^^^^ #{format(constant_msg, name: 'Booking')}
            Booking.count_by_sql('SELECT COUNT(*) FROM bookings')
            ^^^^^^^ #{format(constant_msg, name: 'Booking')}
            add_index :bookings, ::Arel.sql('lower(code)')
                                 ^^^^^^ #{format(constant_msg, name: '::Arel')}
            ActiveRecord::Base.connection.execute('SELECT 1')
            ^^^^^^^^^^^^^^^^^^ #{format(constant_msg, name: 'ActiveRecord::Base')}
          end
        end
      RUBY
    end

    it 'registers an offense for SQL inside reversible and up_only blocks' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            reversible do |direction|
              direction.up { execute 'SELECT 1' }
                             ^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
            end
            up_only { execute 'SELECT 1' }
                      ^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
          end
        end
      RUBY
    end

    it 'registers an offense for SQL inside the migration\'s own helper methods' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            backfill_sources
          end

          private

          def backfill_sources
            execute 'SELECT 1'
            ^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
          end
        end
      RUBY
    end

    it 'registers an offense for calls on instance variables' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            @bookings.update_all(source: 'web')
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'update_all')}
          end
        end
      RUBY
    end

    it 'registers an offense for change_column with a SQL cast, however it is passed' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            change_column :bookings, :date, :date, using: "NULLIF(date, '')::date"
                                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{cast_msg}
            cast = 'date::date'
            change_column :bookings, :date, :date, using: cast
                                                   ^^^^^^^^^^^ #{cast_msg}
            change_column :bookings, :date, :date, **{ using: 'date::date' }
                                                       ^^^^^^^^^^^^^^^^^^^ #{cast_msg}
            change_table :bookings do |t|
              t.change :date, :date, using: 'date::date'
                                     ^^^^^^^^^^^^^^^^^^^ #{cast_msg}
            end
            options = { using: 'date::date' }
            change_column :bookings, :date, :date, **options
                                                   ^^^^^^^^^ #{options_msg}
          end
        end
      RUBY
    end
  end

  describe 'schema statements' do
    it 'accepts schema methods, block variables, check constraints and expression indexes' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          disable_ddl_transaction!

          def change
            create_table :examples do |t|
              t.string :status, null: false, default: 'open'
              t.references :booking, foreign_key: true
              t.timestamps
            end

            add_index :examples, :status, algorithm: :concurrently
            add_index :examples, :status, using: :gin, opclass: :gin_trgm_ops, name: :index_examples_on_status_trgm
            add_index :examples, 'lower(status)', name: :index_examples_on_lower_status
            add_check_constraint :examples, "status IN ('open', 'closed')", name: :examples_status
            change_column_default :examples, :status, from: nil, to: 'open'
            change_column :examples, :status, :text

            %i[opened_at closed_at].each do |column|
              add_column :examples, column, :datetime
            end

            reversible do |direction|
              direction.up { change_column_null :examples, :status, false }
              direction.down { change_column_null :examples, :status, true }
            end
          end
        end
      RUBY
    end

    it 'accepts using as a key inside a JSON default, which is data and not a cast' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            change_column :events, :metadata, :jsonb, default: { using: 'api' }
          end
        end
      RUBY
    end

    it 'accepts class methods and singleton classes, but still checks their bodies' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def self.primary_key_type
            :uuid
          end

          class << self
            def backfill
              execute 'SELECT 1'
              ^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
            end
          end
        end
      RUBY
    end

    it 'accepts qualified references to constants the migration defines itself' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          CONSTRAINT_NAME = :examples_status

          def change
            remove_check_constraint :examples, name: Example::CONSTRAINT_NAME
          end
        end
      RUBY
    end

    it 'accepts calls to methods the migration defines itself' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            add_status_column(:examples)
          end

          private

          def add_status_column(table)
            add_column table, :status, :string unless column_exists?(table, :status)
          end
        end
      RUBY
    end

    it 'accepts constants the migration defines itself and validating constraints later' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          CONSTRAINT_NAME = :examples_status
          STATUSES = %w[open closed].freeze

          def change
            add_check_constraint :examples, "status IN (\#{STATUSES.map { |status| "'\#{status}'" }.join(', ')})",
                                 name: CONSTRAINT_NAME, validate: false
            validate_check_constraint :examples, name: CONSTRAINT_NAME
            add_foreign_key :examples, :bookings, validate: false
            validate_foreign_key :examples, :bookings
          end
        end
      RUBY
    end

    it 'accepts reading the generator configuration, as engine migrations do' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            create_table :examples, id: primary_key_type do |t|
              t.string :status
            end
          end

          private

          def primary_key_type
            config = Rails.configuration.generators
            config.options[config.orm][:primary_key_type] || :primary_key
          end
        end
      RUBY
    end

    it 'accepts reverting another migration' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            revert CreateExamples
          end
        end
      RUBY
    end

    it 'accepts raising an irreversible migration' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def up
            remove_column :examples, :status
          end

          def down
            raise ActiveRecord::IrreversibleMigration
          end
        end
      RUBY
    end

    it 'checks migrations that inherit from ActiveRecord::Migration::Current' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration::Current
          def up
            execute 'SELECT 1'
            ^^^^^^^^^^^^^^^^^^ #{format(call_msg, name: 'execute')}
          end
        end
      RUBY
    end

    it 'ignores classes that are not migrations' do
      expect_no_offenses(<<~RUBY, migration_file)
        class Example
          def up
            execute 'SELECT 1'
          end
        end
      RUBY
    end
  end

  describe 'StartAfter' do
    let(:config) { RuboCop::Config.new('Asjer/MigrationSchemaOnly' => { 'StartAfter' => 20_261_014_120_000 }) }
    let(:source) do
      <<~RUBY
        class Example < ActiveRecord::Migration[8.1]
          def up
            execute 'SELECT 1'
          end
        end
      RUBY
    end

    it 'skips migrations up to and including the configured version' do
      expect_no_offenses(source, 'db/migrate/20261014120000_historical.rb')
    end

    it 'checks migrations after the configured version' do
      expect_offense(<<~RUBY, 'db/migrate/20261014120001_new.rb')
        class Example < ActiveRecord::Migration[8.1]
          def up
            execute 'SELECT 1'
            ^^^^^^^^^^^^^^^^^^ #{unprefixed(format(call_msg, name: 'execute'))}
          end
        end
      RUBY
    end
  end

  describe 'custom allowlists' do
    let(:config) do
      RuboCop::Config.new(
        'Asjer/MigrationSchemaOnly' => { 'AllowedMethods' => %w[create_table], 'AllowedConstants' => %w[Example::Helper] }
      )
    end

    it 'uses the configured methods and constants' do
      expect_offense(<<~RUBY, migration_file)
        class Example < ActiveRecord::Migration[8.1]
          def change
            create_table :examples
            Example::Helper.columns
            add_column :examples, :status, :string
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{unprefixed(format(call_msg, name: 'add_column'))}
          end
        end
      RUBY
    end
  end

  it 'keeps the default configuration in sync with the built-in allowlists' do
    config_file = File.expand_path('../../../../config/default.yml', __dir__)
    defaults = YAML.safe_load_file(config_file)['Asjer/MigrationSchemaOnly']

    expect(defaults).to include('AllowedMethods' => described_class::ALLOWED_METHODS,
                                'AllowedConstants' => described_class::ALLOWED_CONSTANTS)
  end
end
