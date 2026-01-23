# RuboCop Asjer

Custom RuboCop cops: enforce i18n best practices and code quality standards.

## Installation

Add to your application's Gemfile:

```ruby
gem 'rubocop-asjer', require: false
```

Then run:

```bash
bundle install
```

## Usage

Add to your `.rubocop.yml`:

```yaml
plugins:
  - rubocop-asjer
```

> **Note:** The `plugins` directive requires RuboCop 1.72+. For older versions, use `require: rubocop-asjer` instead.

## Available Cops

### Asjer/NoDefaultTranslation

Checks for translation calls that use the `default:` option. Using `default:` bypasses the locale system and can lead to inconsistencies.

```ruby
# bad
t('some.key', default: 'fallback text')
I18n.t('some.key', default: 'fallback')
I18n.translate('some.key', default: t('other.key'))

# good
t('some.key')
I18n.t('some.key')
```

### Asjer/RailsClassOrder

Enforces consistent ordering of declarative methods in Rails models. Methods are grouped into three categories: associations, callbacks, and others. Groups are separated by blank lines.

**Supports autocorrect** with `rubocop -a` or `rubocop -A`.

```ruby
# bad
class User < ApplicationRecord
  belongs_to :plan
  validate :validate_name
  after_create :after_create_1
  has_many :messages
  attr_readonly :email
  after_create :after_create_2
  belongs_to :role
  before_create :set_name
end

# good
class User < ApplicationRecord
  belongs_to :plan
  belongs_to :role
  has_many :messages

  validate :validate_name
  before_create :set_name
  after_create :after_create_1
  after_create :after_create_2

  attr_readonly :email
end
```

By default, this cop only runs on files matching `app/models/**/*.rb`. The method lists are fully configurable:

```yaml
Asjer/RailsClassOrder:
  Associations:
    - belongs_to
    - has_many
    - has_one
    - has_and_belongs_to_many
  Callbacks:
    - after_initialize
    - after_find
    # ... (see config/default.yml for full list)
  Others:
    - attr_readonly
    - serialize
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/asjer/rubocop-asjer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
