# frozen_string_literal: true

RSpec.describe "New features" do
  describe "UUID tables" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :projects, singular: :project, columns: [:name], key: FixtureBot::Key::Uuid
      end
    end

    it "generates UUID primary keys" do
      result = FixtureBot.define(schema) do
        project :alpha do
          name "Alpha"
        end
      end

      id = result.tables[:projects][:alpha][:id]
      expect(id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
    end

    it "produces deterministic UUID keys" do
      result1 = FixtureBot.define(schema) do
        project :alpha do
          name "Alpha"
        end
      end
      result2 = FixtureBot.define(schema) do
        project :alpha do
          name "Alpha"
        end
      end
      expect(result1.tables[:projects][:alpha][:id]).to eq(result2.tables[:projects][:alpha][:id])
    end
  end

  describe "belongs_to with UUID foreign keys" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :projects, singular: :project, columns: [:name], key: FixtureBot::Key::Uuid
        table :tasks, singular: :task, columns: [:title, :project_id] do
          belongs_to :project, table: :projects
        end
      end
    end

    it "resolves FK to UUID value" do
      result = FixtureBot.define(schema) do
        project :alpha do
          name "Alpha"
        end

        task :first do
          title "First task"
          project :alpha
        end
      end

      project_id = result.tables[:projects][:alpha][:id]
      task_project_id = result.tables[:tasks][:first][:project_id]
      expect(task_project_id).to eq(project_id)
      expect(task_project_id).to match(/\A[0-9a-f]{8}-/)
    end
  end

  describe "polymorphic associations" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :posts, singular: :post, columns: [:title]
        table :comments, singular: :comment, columns: [:body]
        table :votes, singular: :vote, columns: [:votable_id, :votable_type, :score] do
          polymorphic :votable
        end
      end
    end

    it "sets both _id and _type columns" do
      result = FixtureBot.define(schema) do
        post :hello do
          title "Hello"
        end

        vote :upvote do
          votable post(:hello)
          score 1
        end
      end

      vote = result.tables[:votes][:upvote]
      post_id = result.tables[:posts][:hello][:id]
      expect(vote[:votable_id]).to eq(post_id)
      expect(vote[:votable_type]).to eq("Post")
      expect(vote[:score]).to eq(1)
    end

    it "works with different target tables" do
      result = FixtureBot.define(schema) do
        post :hello do
          title "Hello"
        end
        comment :nice do
          body "Nice"
        end

        vote :upvote_post do
          votable post(:hello)
          score 1
        end
        vote :upvote_comment do
          votable comment(:nice)
          score 1
        end
      end

      expect(result.tables[:votes][:upvote_post][:votable_type]).to eq("Post")
      expect(result.tables[:votes][:upvote_comment][:votable_type]).to eq("Comment")
      expect(result.tables[:votes][:upvote_post][:votable_id]).to eq(result.tables[:posts][:hello][:id])
      expect(result.tables[:votes][:upvote_comment][:votable_id]).to eq(result.tables[:comments][:nice][:id])
    end
  end

  describe "hardcoded IDs" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name]
        table :posts, singular: :post, columns: [:title, :author_id] do
          belongs_to :author, table: :users
        end
      end
    end

    it "uses the hardcoded ID in the record" do
      result = FixtureBot.define(schema) do
        user :admin do
          id 42
          name "Admin"
        end
      end

      expect(result.tables[:users][:admin][:id]).to eq(42)
    end

    it "FK references resolve to hardcoded value" do
      result = FixtureBot.define(schema) do
        user :admin do
          id 42
          name "Admin"
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
        table :users, singular: :user, columns: [:name], primary_key: :uid
      end
    end

    it "uses the custom PK column name" do
      result = FixtureBot.define(schema) do
        user :admin do
          name "Admin"
        end
      end

      user = result.tables[:users][:admin]
      expect(user).to have_key(:uid)
      expect(user).not_to have_key(:id)
      expect(user[:uid]).to be > 0
    end

    it "allows hardcoding custom PK" do
      result = FixtureBot.define(schema) do
        user :admin do
          uid 99
          name "Admin"
        end
      end

      expect(result.tables[:users][:admin][:uid]).to eq(99)
    end
  end

  describe "custom key strategy" do
    it "accepts any object responding to #generate" do
      custom_strategy = Object.new
      def custom_strategy.generate(table_name, record_name)
        "#{table_name}-#{record_name}".hash.abs
      end

      schema = FixtureBot::Schema.define do
        table :items, singular: :item, columns: [:name], key: custom_strategy
      end

      result = FixtureBot.define(schema) do
        item :first do
          name "First"
        end
      end

      expected = custom_strategy.generate(:items, :first)
      expect(result.tables[:items][:first][:id]).to eq(expected)
    end
  end

  describe "mixed integer and UUID tables" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name]
        table :api_keys, singular: :api_key, columns: [:token, :user_id], key: FixtureBot::Key::Uuid do
          belongs_to :user, table: :users
        end
      end
    end

    it "integer table has integer PK, UUID table has UUID PK" do
      result = FixtureBot.define(schema) do
        user :admin do
          name "Admin"
        end

        api_key :main do
          token "abc123"
          user :admin
        end
      end

      user_id = result.tables[:users][:admin][:id]
      api_key_id = result.tables[:api_keys][:main][:id]

      expect(user_id).to be_a(::Integer)
      expect(api_key_id).to be_a(String)
      expect(api_key_id).to match(/\A[0-9a-f]{8}-/)

      # FK from UUID table to integer table should be integer
      expect(result.tables[:api_keys][:main][:user_id]).to eq(user_id)
    end
  end

  describe "polymorphic? duck type" do
    it "BelongsTo is not polymorphic" do
      assoc = FixtureBot::Schema::BelongsTo.new(name: :author, table: :users, foreign_key: :author_id)
      expect(assoc.polymorphic?).to be false
    end

    it "PolymorphicBelongsTo is polymorphic" do
      assoc = FixtureBot::Schema::PolymorphicBelongsTo.new(name: :votable, foreign_key: :votable_id, foreign_type: :votable_type)
      expect(assoc.polymorphic?).to be true
    end

    it "Table filters by polymorphic?" do
      schema = FixtureBot::Schema.define do
        table :posts, singular: :post, columns: [:title]
        table :votes, singular: :vote, columns: [:votable_id, :votable_type, :voter_id] do
          polymorphic :votable
          belongs_to :voter, table: :posts
        end
      end

      table = schema.tables[:votes]
      expect(table.belongs_to_associations.map(&:name)).to eq([:voter])
      expect(table.polymorphic_associations.map(&:name)).to eq([:votable])
    end
  end
end
