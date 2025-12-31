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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/asjer/rubocop-asjer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
