# Changelog

## 0.3.0

### Added

- **UUID primary keys.** Tables with UUID primary keys are auto-detected in Rails. For manual schemas, pass `key: FixtureBot::Key::Uuid`. Generates deterministic UUID v5 values.
- **Polymorphic associations.** Use `votable post(:hello)` to set both `votable_id` and `votable_type: "Post"`. Auto-detected in Rails from `_id`/`_type` column pairs without foreign key constraints. For manual schemas, declare with `polymorphic :votable`.
- **Custom key strategies.** Any module or object responding to `generate(table_name, record_name)` can be passed as `key:` on a table definition.
- **Custom primary key columns.** Tables using a column other than `id` as the primary key are auto-detected in Rails. For manual schemas, pass `primary_key: :uid`.
- **Hardcoded IDs.** Set `id 42` in a record block to override the generated key. Foreign key references resolve to the hardcoded value.

### Internals

- Key generation strategies (`Key::Integer`, `Key::Uuid`) are stateless modules instead of a single `Key.generate` method.
- All association types share a unified `resolve(ref, keys)` interface.
- `KeyRegistry` pre-computes primary key values for all records.
- `Default::Generator` wraps generator blocks instead of passing raw procs.
- Foreign key naming conventions (`_id`, `_type`) live as class methods on `BelongsTo` and `PolymorphicBelongsTo`.
- File-based `define` uses thread-local state instead of module-level `@pending_blocks`.

## 0.2.0

### Breaking changes

- **Generator block parameter:** Generator blocks now receive a `fixture` object as a block parameter instead of the magic `name` method. Use `fixture.key` to get the record's symbol name. Column values are available as bare methods inside the block.

  ```ruby
  # Before
  user.email { "#{name}@example.com" }

  # After
  user.email { |fixture| "#{fixture.key}@example.com" }
  ```

### Improvements

- Rename `YamlDumper` to `Compiler`, `generate`/`dump` to `compile`
- Rename rake task from `fixturebot:generate` to `fixturebot:compile`
- Strip YAML document prefix (`---`) from compiled output
- Fix CLI entrypoint to detect Rails app instead of rescuing LoadError
- Internal refactor: group classes into `Row` and `Default` modules, replace `method_missing` with `define_singleton_method`

## 0.1.1

- Internal refactoring and README updates

## 0.1.0

- Initial release
- Ruby DSL for defining fixtures with generators, associations, and join tables
- Auto-generates YAML fixture files from database schema
- RSpec and Minitest integration with auto-generation hooks
- Rails Railtie with `config.fixturebot` namespace and `fixturebot:generate` rake task
- Install generator: `rails generate fixturebot:install`
