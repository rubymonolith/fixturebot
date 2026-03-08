# FixtureBot

The syntactic sugar of factories with the speed of fixtures.

FixtureBot lets you define your test data in a Ruby DSL and compiles it into standard Rails fixture YAML files. The generated YAML is deterministic and should be checked into git, just like a lockfile. Your tests never see FixtureBot at runtime; Rails just loads the YAML fixtures as usual.

**Features:**

- **Ruby DSL** for defining records, associations, and join tables
- **Generators** for filling in required columns (like email) across all records
- **Stable IDs** so foreign keys are consistent and diffs are clean across runs
- **UUID support** for tables with UUID primary keys
- **Polymorphic associations** with automatic type column resolution
- **Schema auto-detection** from your Rails database (no manual column lists)
- **Auto-generates** before your test suite runs (RSpec and Minitest)

## Read the article

More background at [BeautifulRuby.com](https://beautifulruby.com/code/fixturebot).

[![Screenshot of Don't throw the specs out with the factories article](https://immutable.terminalwire.com/frotvIWicKOgyNTufNGKSjpaI3RecS7IoO4hAWFycOC4zMopBylYljvcg62Br7NGHwsMikw3U5eLxQ0CpI7aVaVkLNLhCYK6OYI9.jpeg)](https://beautifulruby.com/code/fixturebot)

## Quick example

```ruby
# spec/fixtures.rb
FixtureBot.define do
  # Generators fill in required columns so you don't have to repeat yourself.
  # |fixture| gives you the fixture key; bare methods give column values.
  user.email { |fixture| "#{fixture.key}@example.com" }

  user :brad do
    name "Brad"
    email "brad@example.com"  # overrides the generator
  end

  user :alice do
    name "Alice"              # email filled in by generator: "alice@example.com"
  end

  user :deactivated do
    name "Ghost"
    email nil                 # explicit nil, generator skipped, email set to null
  end

  post :hello_world do
    title "Hello World"
    body "Welcome to the blog!"
    author :brad              # sets author_id to brad's stable ID
    tags :ruby, :rails        # creates rows in posts_tags
  end

  tag.name { |fixture| fixture.key.to_s.capitalize }

  tag :ruby                   # name: "Ruby"
  tag :rails                  # name: "Rails"
end
```

This generates YAML files like `users.yml`, `posts.yml`, `tags.yml`, and `posts_tags.yml` in your fixtures directory. Use them in tests like any other fixture:

```ruby
# RSpec
RSpec.describe Post, type: :model do
  fixtures :all

  it "belongs to an author" do
    post = posts(:hello_world)
    expect(post.author).to eq(users(:brad))
  end
end

# Minitest
class PostTest < ActiveSupport::TestCase
  def test_belongs_to_author
    post = posts(:hello_world)
    assert_equal users(:brad), post.author
  end
end
```

## Installation

Add to your Gemfile:

```ruby
gem "fixturebot-rails"
```

### Rails generator

The easiest way to get started:

```bash
rails generate fixturebot:install
```

This creates `spec/fixtures.rb` (RSpec) or `test/fixtures.rb` (Minitest) with a skeleton DSL file and adds the appropriate require to your test helper.

### Manual setup

#### RSpec

Add to `spec/rails_helper.rb`:

```ruby
require "fixturebot/rspec"
```

Create `spec/fixtures.rb` with your fixture definitions.

Fixtures are auto-generated before each suite run, no rake task needed.

#### Minitest

Add to `test/test_helper.rb`:

```ruby
require "fixturebot/minitest"
```

Create `test/fixtures.rb` with your fixture definitions.

Fixtures are auto-generated when the helper is loaded, no rake task needed.

### Rake task

A `fixturebot:compile` rake task is also available if you prefer manual control:

```bash
bundle exec rake fixturebot:compile
```

### Configuration

FixtureBot auto-detects your fixtures file (`test/fixtures.rb` or `spec/fixtures.rb`) and derives the output directory by stripping `.rb` (e.g. `spec/fixtures.rb` writes to `spec/fixtures/`). To override:

```ruby
# config/application.rb or config/environments/test.rb
config.fixturebot.fixtures_file = "test/my_fixtures.rb"
config.fixturebot.output_dir = "test/fixtures"
```

## The DSL

### Records

Define named records with literal column values:

```ruby
FixtureBot.define do
  user :brad do
    name "Brad"
    email "brad@example.com"
  end
end
```

Records without a block get an auto-generated ID and any generator defaults:

```ruby
FixtureBot.define do
  user.email { |fixture| "#{fixture.key}@example.com" }

  user :alice
  # => { id: <stable_id>, email: "alice@example.com" }
end
```

### Generators

Generators set default column values. They run for each record that doesn't explicitly set that column. Generators are never created implicitly; columns without a value or generator are omitted from the YAML output (Rails uses the database column default).

```ruby
FixtureBot.define do
  user.email { |fixture| "#{fixture.key}@example.com" }
end
```

The generator block receives a `fixture` object with a `key` method (the record's symbol name). Bare methods inside the block refer to column values set on the record:

```ruby
FixtureBot.define do
  user.display_name { |fixture| "#{fixture.key} (#{email})" }
end
```

When a generator covers all the columns you need, records don't need a block at all:

```ruby
FixtureBot.define do
  tag.name { |fixture| fixture.key.to_s.capitalize }

  tag :ruby     # name: "Ruby"
  tag :rails    # name: "Rails"
  tag :testing  # name: "Testing"
end
```

A literal value shadows the generator. An explicit `nil` also shadows it:

```ruby
FixtureBot.define do
  user.email { |fixture| "#{fixture.key}@example.com" }

  user :brad do
    name "Brad"
    email "brad@hey.com"  # literal, skips the generator
  end

  user :alice do
    name "Alice"
    # no email set, generator produces "alice@example.com"
  end

  user :deactivated do
    name "Ghost"
    email nil              # explicit nil, skips the generator, sets email to null
  end
end
```

### Associations

Reference other records by name for `belongs_to`:

```ruby
FixtureBot.define do
  post :hello_world do
    title "Hello World"
    author :brad  # sets author_id to brad's stable ID
  end
end
```

### Polymorphic associations

For polymorphic `belongs_to`, reference the target using its table helper to set both `_id` and `_type` columns:

```ruby
FixtureBot.define do
  post :hello do
    title "Hello"
  end

  comment :nice do
    body "Nice post"
  end

  vote :upvote_post do
    votable post(:hello)       # sets votable_id and votable_type: "Post"
  end

  vote :upvote_comment do
    votable comment(:nice)     # sets votable_id and votable_type: "Comment"
  end
end
```

In the manual schema, declare polymorphic associations with `polymorphic`:

```ruby
FixtureBot::Schema.define do
  table :posts, singular: :post, columns: [:title]
  table :comments, singular: :comment, columns: [:body]

  table :votes, singular: :vote, columns: [:votable_id, :votable_type, :voter_id] do
    polymorphic :votable
    belongs_to :voter, table: :users
  end
end
```

In Rails, polymorphic associations are auto-detected from `_id`/`_type` column pairs that don't have a foreign key constraint.

### Join tables (HABTM)

Reference multiple records for join table associations:

```ruby
FixtureBot.define do
  post :hello_world do
    title "Hello World"
    tags :ruby, :rails  # creates rows in posts_tags
  end
end
```

### Hardcoded IDs

By default, FixtureBot generates stable IDs deterministically from the table and record name. You can override this with an explicit value:

```ruby
FixtureBot.define do
  user :admin do
    id 42
    name "Admin"
  end

  post :hello do
    title "Hello"
    author :admin  # author_id resolves to 42
  end
end
```

### UUID primary keys

Tables with UUID primary keys work automatically in Rails (detected from the column type). In the manual schema, pass `key: FixtureBot::Key::Uuid`:

```ruby
FixtureBot::Schema.define do
  table :projects, singular: :project, columns: [:name], key: FixtureBot::Key::Uuid
end
```

FixtureBot generates deterministic UUID v5 values, so the output is stable across runs.

You can also provide your own key strategy — any object (or module) that responds to `generate(table_name, record_name)`. For example, Stripe-style prefixed IDs:

```ruby
module PrefixedKey
  module_function

  def generate(table_name, record_name)
    hash = Zlib.crc32("#{table_name}:#{record_name}").to_s(36)
    "#{table_name.to_s.chomp('s')}_#{hash}"
  end
end

FixtureBot::Schema.define do
  table :customers, singular: :customer, columns: [:name], key: PrefixedKey
  # => customer_id: "customer_1a2b3c"
end
```

### Custom primary key column

If your table uses a column other than `id` as the primary key:

```ruby
FixtureBot::Schema.define do
  table :users, singular: :user, columns: [:name], primary_key: :uid
end
```

In Rails, this is auto-detected from the database.

### Implicit vs explicit style

By default, the block is evaluated implicitly. Table methods like `user` and `post` are available directly:

```ruby
FixtureBot.define do
  user :brad do
    name "Brad"
  end
end
```

If you prefer an explicit receiver (useful for editor autocompletion or clarity in large files), pass a block argument:

```ruby
FixtureBot.define do |t|
  t.user :brad do
    name "Brad"
  end
end
```

Both styles are equivalent. Record blocks (the inner `do...end`) are always implicit.

### Schema

FixtureBot reads your database schema automatically in Rails. Outside of Rails, you can define it by hand:

```ruby
FixtureBot::Schema.define do
  table :users, singular: :user, columns: [:name, :email]

  table :posts, singular: :post, columns: [:title, :body, :author_id] do
    belongs_to :author, table: :users
  end

  table :tags, singular: :tag, columns: [:name]

  join_table :posts_tags, :posts, :tags
end
```

## Prior art

### [Rails fixtures](https://guides.rubyonrails.org/testing.html#the-low-down-on-fixtures)

Rails fixtures are YAML files that get loaded into the database once before your test suite runs. Each test wraps in a transaction and rolls back, so the data is always clean and tests are fast. This is the approach FixtureBot builds on.

The problem is writing YAML by hand. Foreign keys are magic strings (`author: brad`), there's no way to DRY up repeated columns, and large fixture files are hard to read. FixtureBot gives you a Ruby DSL that compiles down to the same YAML, so you keep the speed of fixtures without the pain of maintaining them.

### [FactoryBot](https://github.com/thoughtbot/factory_bot)

FactoryBot creates records on the fly inside each test. You call `create(:user)` and it inserts a row. This makes tests self-contained and easy to read, but it's slow. Every test that needs data pays the cost of inserting records, and complex object graphs lead to cascading `create` calls.

FixtureBot borrows the DSL feel of FactoryBot (named records, associations by symbol, default generators) but compiles to fixtures instead of inserting at runtime. You get the ergonomics of factories with the speed of fixtures.

### [Oaken](https://github.com/kaspth/oaken)

Oaken and FixtureBot share the same motivation: replace hand-written YAML fixtures with a Ruby DSL. They take very different approaches.

**Oaken inserts records into the database** at runtime using `ActiveRecord::Base#create!`. It also supports loading different seed files per test case (`seed "cases/pagination"`), which means your data set can vary across tests. This flexibility comes at a cost: you lose the "load once, wrap every test in a transaction" speed advantage that makes Rails fixtures fast. It's closer to factories in that regard, with more structure around organizing seed scripts.

**FixtureBot is more opinionated.** One fixture file, one data set, compiled to plain YAML and checked into git. At test time, FixtureBot is out of the picture entirely. Rails loads the YAML fixtures once and wraps each test in a transaction as usual. No runtime dependency, no per-test seeding, no seed file organization to manage.

| | FixtureBot | Rails fixtures | FactoryBot | Oaken |
|---|---|---|---|---|
| **Define data in** | Ruby DSL | YAML | Ruby DSL | Ruby scripts |
| **Output** | YAML files in git | YAML files in git | Database rows per test | Database rows at boot |
| **Runtime dependency** | None | None | Required per test | Required at boot |
| **Data set** | One set, loaded once | One set, loaded once | Built per test | Per-test via seed files |
| **Speed** | Fast (fixtures) | Fast (fixtures) | Slow (inserts per test) | Varies |
| **Stable IDs** | Deterministic | Deterministic | Database-assigned | Database-assigned |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

Try the playground without Rails:

```bash
bundle exec exe/fixturebot show ./playground/blog
```
