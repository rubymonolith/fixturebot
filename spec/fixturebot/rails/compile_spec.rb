# frozen_string_literal: true

require "fixturebot/rails"
require "tmpdir"

RSpec.describe FixtureBot::Rails, ".compile" do
  before do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

    ActiveRecord::Schema.define(version: 2024_01_01_000000) do
      create_table "users", force: :cascade do |t|
        t.string "name"
        t.string "email"
        t.timestamps
      end

      create_table "posts", force: :cascade do |t|
        t.string "title"
        t.text "body"
        t.integer "author_id"
        t.timestamps
      end

      add_foreign_key "posts", "users", column: "author_id"
    end
  end

  after do
    ActiveRecord::Base.connection_pool.disconnect!
  end

  it "compiles YAML fixture files from a DSL file" do
    Dir.mktmpdir do |tmpdir|
      fixtures_file = File.join(tmpdir, "fixtures.rb")
      output_dir = File.join(tmpdir, "fixtures")

      File.write(fixtures_file, <<~RUBY)
        FixtureBot.define do
          user :alice do
            name "Alice"
            email "alice@example.com"
          end

          user :bob do
            name "Bob"
            email "bob@example.com"
          end

          post :hello do
            title "Hello World"
            body "First post"
            author :alice
          end
        end
      RUBY

      described_class.compile(fixtures_file: fixtures_file, output_dir: output_dir)

      users_yaml = YAML.load_file(File.join(output_dir, "users.yml"))
      expect(users_yaml.keys).to contain_exactly("alice", "bob")
      expect(users_yaml["alice"]["name"]).to eq("Alice")
      expect(users_yaml["alice"]["email"]).to eq("alice@example.com")
      expect(users_yaml["bob"]["name"]).to eq("Bob")

      posts_yaml = YAML.load_file(File.join(output_dir, "posts.yml"))
      expect(posts_yaml.keys).to contain_exactly("hello")
      expect(posts_yaml["hello"]["title"]).to eq("Hello World")
    end
  end

  it "skips empty tables" do
    Dir.mktmpdir do |tmpdir|
      fixtures_file = File.join(tmpdir, "fixtures.rb")
      output_dir = File.join(tmpdir, "fixtures")

      File.write(fixtures_file, <<~RUBY)
        FixtureBot.define do
          user :alice do
            name "Alice"
            email "alice@example.com"
          end
        end
      RUBY

      described_class.compile(fixtures_file: fixtures_file, output_dir: output_dir)

      expect(File.exist?(File.join(output_dir, "users.yml"))).to be true
      expect(File.exist?(File.join(output_dir, "posts.yml"))).to be false
    end
  end

  it "returns early when fixtures file does not exist" do
    Dir.mktmpdir do |tmpdir|
      output_dir = File.join(tmpdir, "fixtures")

      described_class.compile(
        fixtures_file: File.join(tmpdir, "nonexistent.rb"),
        output_dir: output_dir
      )

      expect(Dir.exist?(output_dir)).to be false
    end
  end

  it "compiles from multiple fixture files" do
    Dir.mktmpdir do |tmpdir|
      users_file = File.join(tmpdir, "users.rb")
      posts_file = File.join(tmpdir, "posts.rb")
      output_dir = File.join(tmpdir, "fixtures")

      File.write(users_file, <<~RUBY)
        FixtureBot.define do
          user :alice do
            name "Alice"
            email "alice@example.com"
          end
        end
      RUBY

      File.write(posts_file, <<~RUBY)
        FixtureBot.define do
          post :hello do
            title "Hello World"
            body "First post"
            author :alice
          end
        end
      RUBY

      described_class.compile(
        fixtures_file: [users_file, posts_file],
        output_dir: output_dir
      )

      users_yaml = YAML.load_file(File.join(output_dir, "users.yml"))
      expect(users_yaml.keys).to contain_exactly("alice")
      expect(users_yaml["alice"]["name"]).to eq("Alice")

      posts_yaml = YAML.load_file(File.join(output_dir, "posts.yml"))
      expect(posts_yaml.keys).to contain_exactly("hello")
      expect(posts_yaml["hello"]["title"]).to eq("Hello World")
    end
  end

  it "merges defaults from a base file with records from domain files" do
    Dir.mktmpdir do |tmpdir|
      base_file = File.join(tmpdir, "base.rb")
      users_file = File.join(tmpdir, "users.rb")
      output_dir = File.join(tmpdir, "fixtures")

      File.write(base_file, <<~RUBY)
        FixtureBot.define do
          user.email { |fixture| "\#{fixture.key}@example.com" }
        end
      RUBY

      File.write(users_file, <<~RUBY)
        FixtureBot.define do
          user :alice do
            name "Alice"
          end

          user :bob do
            name "Bob"
          end
        end
      RUBY

      described_class.compile(
        fixtures_file: [base_file, users_file],
        output_dir: output_dir
      )

      users_yaml = YAML.load_file(File.join(output_dir, "users.yml"))
      expect(users_yaml["alice"]["name"]).to eq("Alice")
      expect(users_yaml["alice"]["email"]).to eq("alice@example.com")
      expect(users_yaml["bob"]["email"]).to eq("bob@example.com")
    end
  end

  it "allows later files to override defaults from earlier files" do
    Dir.mktmpdir do |tmpdir|
      base_file = File.join(tmpdir, "base.rb")
      override_file = File.join(tmpdir, "override.rb")
      output_dir = File.join(tmpdir, "fixtures")

      File.write(base_file, <<~RUBY)
        FixtureBot.define do
          user.email { "default@example.com" }
        end
      RUBY

      File.write(override_file, <<~RUBY)
        FixtureBot.define do
          user.email { "overridden@example.com" }

          user :alice do
            name "Alice"
          end
        end
      RUBY

      described_class.compile(
        fixtures_file: [base_file, override_file],
        output_dir: output_dir
      )

      users_yaml = YAML.load_file(File.join(output_dir, "users.yml"))
      expect(users_yaml["alice"]["email"]).to eq("overridden@example.com")
    end
  end
end
