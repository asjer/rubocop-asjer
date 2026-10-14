# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Asjer::ExplicitMigrationVersionInSpec, :config do
  let(:config) { RuboCop::Config.new }
  let(:msg) do
    'Asjer/ExplicitMigrationVersionInSpec: Run migrations to an explicit version, e.g. ' \
      '`migration_context.run(:down, VERSION)`; `%<name>s` depends on the latest migration.'
  end

  it 'registers an offense for rollback and forward' do
    expect_offense(<<~RUBY)
      connection.pool.migration_context.rollback(1)
                                        ^^^^^^^^ #{format(msg, name: 'rollback')}
      context = connection.pool.migration_context
      context
        .forward
         ^^^^^^^ #{format(msg, name: 'forward')}
    RUBY
  end

  it 'registers an offense for migrate without a version or with nil' do
    expect_offense(<<~RUBY)
      migration_context.migrate
                        ^^^^^^^ #{format(msg, name: 'migrate')}
      migration_context&.migrate(nil)
                         ^^^^^^^ #{format(msg, name: 'migrate')}
    RUBY
  end

  it 'accepts running to an explicit version' do
    expect_no_offenses(<<~RUBY)
      connection.pool.migration_context.run(:down, 20261012170000)
      migration_context.migrate(20261012170000)
      CreateExamples.new.migrate(:up)
      raise ActiveRecord::Rollback
    RUBY
  end
end
