# frozen_string_literal: true

RSpec.describe FixtureBot do
  it "has a version number" do
    expect(FixtureBot::VERSION).not_to be nil
  end

  describe ".define" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
        table :posts, singular: :post, columns: [:title, :body, :author_id] do
          belongs_to :author, table: :users
        end
        table :tags, singular: :tag, columns: [:name]
        join_table :posts_tags, :posts, :tags
      end
    end

    let(:result) do
      FixtureBot.define(schema) do
        user.email { |fixture| "#{fixture.key}@blog.test" }

        user :admin do
          name "Brad"
          email "brad@blog.test"
        end

        user :reader do
          name "Alice"
        end

        post :hello_world do
          title "Hello world"
          body "Welcome to my blog."
          author :admin
          tags :ruby, :rails
        end

        tag :ruby do
          name "ruby"
        end

        tag :rails do
          name "rails"
        end
      end
    end

    it "produces the expected users" do
      users = result.tables[:users]

      expect(users[:admin][:name]).to eq("Brad")
      expect(users[:admin][:email]).to eq("brad@blog.test")

      expect(users[:reader][:name]).to eq("Alice")
      expect(users[:reader][:email]).to eq("reader@blog.test")
    end

    it "produces the expected posts with belongs_to" do
      posts = result.tables[:posts]
      admin_id = result.tables[:users][:admin][:id]

      expect(posts[:hello_world][:title]).to eq("Hello world")
      expect(posts[:hello_world][:body]).to eq("Welcome to my blog.")
      expect(posts[:hello_world][:author_id]).to eq(admin_id)
    end

    it "produces the expected tags" do
      tags = result.tables[:tags]
      expect(tags[:ruby][:name]).to eq("ruby")
      expect(tags[:rails][:name]).to eq("rails")
    end

    it "produces HABTM join table rows" do
      join = result.tables[:posts_tags]
      post_id = result.tables[:posts][:hello_world][:id]
      ruby_id = result.tables[:tags][:ruby][:id]
      rails_id = result.tables[:tags][:rails][:id]

      expect(join[:hello_world_ruby]).to eq({post_id: post_id, tag_id: ruby_id})
      expect(join[:hello_world_rails]).to eq({post_id: post_id, tag_id: rails_id})
    end
  end

  describe FixtureBot::Key::Integer do
    subject(:key) { described_class.new }

    it "generates deterministic IDs" do
      id1 = key.generate(:users, :admin)
      id2 = key.generate(:users, :admin)
      expect(id1).to eq(id2)
    end

    it "generates positive integers" do
      id = key.generate(:users, :admin)
      expect(id).to be > 0
    end

    it "generates different IDs for different records" do
      id1 = key.generate(:users, :admin)
      id2 = key.generate(:users, :reader)
      expect(id1).not_to eq(id2)
    end
  end

  describe FixtureBot::Key::UUID do
    subject(:key) { described_class.new }

    it "generates deterministic UUIDs" do
      uuid1 = key.generate(:users, :admin)
      uuid2 = key.generate(:users, :admin)
      expect(uuid1).to eq(uuid2)
    end

    it "generates valid UUID v5 format" do
      uuid = key.generate(:users, :admin)
      expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    it "generates different UUIDs for different records" do
      uuid1 = key.generate(:users, :admin)
      uuid2 = key.generate(:users, :reader)
      expect(uuid1).not_to eq(uuid2)
    end

    it "generates different UUIDs for same name in different tables" do
      uuid1 = key.generate(:users, :admin)
      uuid2 = key.generate(:posts, :admin)
      expect(uuid1).not_to eq(uuid2)
    end
  end

  describe FixtureBot::Key, ".resolve" do
    it "resolves :integer to Key::Integer" do
      expect(FixtureBot::Key.resolve(:integer)).to be_a(FixtureBot::Key::Integer)
    end

    it "resolves :uuid to Key::UUID" do
      expect(FixtureBot::Key.resolve(:uuid)).to be_a(FixtureBot::Key::UUID)
    end

    it "passes through objects responding to #generate" do
      custom = Object.new
      def custom.generate(table_name, record_name) = 1
      expect(FixtureBot::Key.resolve(custom)).to be(custom)
    end

    it "raises ArgumentError for unsupported symbols" do
      expect { FixtureBot::Key.resolve(:bigint) }.to raise_error(ArgumentError, /unsupported primary key type/)
    end

    it "raises ArgumentError for objects not responding to #generate" do
      expect { FixtureBot::Key.resolve("not a key") }.to raise_error(ArgumentError, /respond to #generate/)
    end
  end

  describe "UUID primary key support" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email], primary_key_type: :uuid
        table :posts, singular: :post, columns: [:title, :author_id], primary_key_type: :uuid do
          belongs_to :author, table: :users
        end
        table :tags, singular: :tag, columns: [:name], primary_key_type: :uuid
        join_table :posts_tags, :posts, :tags
      end
    end

    let(:result) do
      FixtureBot.define(schema) do
        user :admin do
          name "Brad"
          email "brad@blog.test"
        end

        post :hello_world do
          title "Hello world"
          author :admin
          tags :ruby
        end

        tag :ruby do
          name "ruby"
        end
      end
    end

    it "generates UUID primary keys" do
      uuid = result.tables[:users][:admin][:id]
      expect(uuid).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    it "generates UUID foreign keys for belongs_to" do
      admin_uuid = result.tables[:users][:admin][:id]
      post_author_id = result.tables[:posts][:hello_world][:author_id]
      expect(post_author_id).to eq(admin_uuid)
    end

    it "generates UUID foreign keys in join tables" do
      post_uuid = result.tables[:posts][:hello_world][:id]
      tag_uuid = result.tables[:tags][:ruby][:id]
      join = result.tables[:posts_tags][:hello_world_ruby]

      expect(join[:post_id]).to eq(post_uuid)
      expect(join[:tag_id]).to eq(tag_uuid)
    end
  end

  describe "mixed integer and UUID primary keys" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :tenants, singular: :tenant, columns: [:name], primary_key_type: :uuid
        table :posts, singular: :post, columns: [:title, :tenant_id] do
          belongs_to :tenant, table: :tenants
        end
      end
    end

    let(:result) do
      FixtureBot.define(schema) do
        tenant :acme do
          name "Acme Corp"
        end

        post :hello do
          title "Hello"
          tenant :acme
        end
      end
    end

    it "generates integer ID for integer table" do
      post_id = result.tables[:posts][:hello][:id]
      expect(post_id).to be_a(Integer)
    end

    it "generates UUID for UUID table" do
      tenant_id = result.tables[:tenants][:acme][:id]
      expect(tenant_id).to match(/\A[0-9a-f]{8}-/)
    end

    it "uses UUID when referencing a UUID table from an integer table" do
      tenant_uuid = result.tables[:tenants][:acme][:id]
      post_tenant_id = result.tables[:posts][:hello][:tenant_id]
      expect(post_tenant_id).to eq(tenant_uuid)
    end
  end

  describe "generators" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
      end
    end

    it "accesses column values as methods" do
      result = FixtureBot.define(schema) do
        user.email { "#{name.downcase}@blog.test" }

        user :admin do
          name "Brad"
        end
      end

      expect(result.tables[:users][:admin][:email]).to eq("brad@blog.test")
    end

    it "preserves explicit nil over generator" do
      result = FixtureBot.define(schema) do
        user.email { |fixture| "#{fixture.key}@blog.test" }

        user :admin do
          name "Brad"
          email nil
        end
      end

      expect(result.tables[:users][:admin][:email]).to be_nil
    end

    it "receives a fixture object as block parameter" do
      result = FixtureBot.define(schema) do
        user.email { |fixture| "#{fixture.key}@blog.test" }

        user :alice
      end

      expect(result.tables[:users][:alice][:email]).to eq("alice@blog.test")
    end
  end

  describe "unknown method errors" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
      end
    end

    it "raises NoMethodError for unknown table methods" do
      expect {
        FixtureBot.define(schema) do
          widget :foo
        end
      }.to raise_error(NoMethodError)
    end

    it "raises NoMethodError for unknown column in row DSL" do
      expect {
        FixtureBot.define(schema) do
          user :admin do
            unknown_column "value"
          end
        end
      }.to raise_error(NoMethodError)
    end

    it "raises NoMethodError for unknown column on generator proxy" do
      expect {
        FixtureBot.define(schema) do
          user.nonexistent { "value" }
        end
      }.to raise_error(NoMethodError)
    end
  end

  describe "primary_key_type validation" do
    it "raises ArgumentError for unsupported primary key type symbol" do
      expect {
        FixtureBot::Schema.define do
          table :users, singular: :user, columns: [:name], primary_key_type: :bigint
        end
      }.to raise_error(ArgumentError, /unsupported primary key type: :bigint/)
    end

    it "raises ArgumentError for objects not responding to #generate" do
      not_a_key = Object.new
      expect {
        FixtureBot::Schema.define do
          table :users, singular: :user, columns: [:name], primary_key_type: not_a_key
        end
      }.to raise_error(ArgumentError, /respond to #generate/)
    end

    it "accepts a custom Key strategy object" do
      custom = Object.new
      def custom.generate(table_name, record_name) = 1

      schema = FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name], primary_key_type: custom
      end

      expect(schema.tables[:users].primary_key_type).to be(custom)
    end
  end

  describe "hardcoded IDs" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name, :email]
        table :posts, singular: :post, columns: [:title, :author_id] do
          belongs_to :author, table: :users
        end
      end
    end

    it "uses the hardcoded integer id" do
      result = FixtureBot.define(schema) do
        user :admin do
          id 42
          name "Brad"
        end
      end

      expect(result.tables[:users][:admin][:id]).to eq(42)
    end

    it "uses the hardcoded string id" do
      result = FixtureBot.define(schema) do
        user :admin do
          id "550e8400-e29b-41d4-a716-446655440000"
          name "Brad"
        end
      end

      expect(result.tables[:users][:admin][:id]).to eq("550e8400-e29b-41d4-a716-446655440000")
    end

    it "falls back to generated id when not hardcoded" do
      result = FixtureBot.define(schema) do
        user :admin do
          name "Brad"
        end
      end

      expect(result.tables[:users][:admin][:id]).to be_a(Integer)
    end

    it "resolves belongs_to references to hardcoded ids" do
      result = FixtureBot.define(schema) do
        user :admin do
          id 42
          name "Brad"
        end

        post :hello do
          title "Hello"
          author :admin
        end
      end

      expect(result.tables[:posts][:hello][:author_id]).to eq(42)
    end
  end

  describe "custom primary key column" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name],
          primary_key_type: :uuid, primary_key_column: :custom_primary_key_col
        table :posts, singular: :post, columns: [:title, :author_id] do
          belongs_to :author, table: :users
        end
      end
    end

    it "uses the custom column name in record output" do
      result = FixtureBot.define(schema) do
        user :admin do
          name "Brad"
        end
      end

      admin = result.tables[:users][:admin]
      expect(admin).to have_key(:custom_primary_key_col)
      expect(admin).not_to have_key(:id)
      expect(admin[:custom_primary_key_col]).to match(/\A[0-9a-f]{8}-/)
    end

    it "allows hardcoding via the custom column name" do
      result = FixtureBot.define(schema) do
        user :admin do
          custom_primary_key_col "550e8400-e29b-41d4-a716-446655440000"
          name "Brad"
        end
      end

      expect(result.tables[:users][:admin][:custom_primary_key_col]).to eq("550e8400-e29b-41d4-a716-446655440000")
    end

    it "resolves belongs_to foreign keys to the hardcoded value" do
      result = FixtureBot.define(schema) do
        user :admin do
          custom_primary_key_col "550e8400-e29b-41d4-a716-446655440000"
          name "Brad"
        end

        post :hello do
          title "Hello"
          author :admin
        end
      end

      expect(result.tables[:posts][:hello][:author_id]).to eq("550e8400-e29b-41d4-a716-446655440000")
    end
  end
end
