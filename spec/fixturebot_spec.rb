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

      expect(join[:hello_world_ruby]).to eq({ post_id: post_id, tag_id: ruby_id })
      expect(join[:hello_world_rails]).to eq({ post_id: post_id, tag_id: rails_id })
    end
  end

  describe "polymorphic associations" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name]

        table :posts, singular: :post, columns: [:title, :author_id] do
          belongs_to :author, table: :users
        end

        table :votes, singular: :vote, columns: [:user_id, :votable_id, :votable_type] do
          belongs_to :user, table: :users
        end
      end
    end

    it "produces votes with polymorphic references" do
      result = FixtureBot.define(schema) do
        user :alice do
          name "Alice"
        end

        post :hello do
          title "Hello World"
          author :alice
        end

        vote :like do
          user :alice
          votable post(:hello)
        end
      end

      votes = result.tables[:votes]
      post_id = result.tables[:posts][:hello][:id]
      user_id = result.tables[:users][:alice][:id]

      expect(votes[:like][:user_id]).to eq(user_id)
      expect(votes[:like][:votable_id]).to eq(post_id)
      expect(votes[:like][:votable_type]).to eq("Post")
    end

    it "supports polymorphic references to different table types" do
      result = FixtureBot.define(schema) do
        user :bob do
          name "Bob"
        end

        post :tech do
          title "Tech Post"
          author :bob
        end

        vote :post_vote do
          user :bob
          votable post(:tech)
        end
      end

      votes = result.tables[:votes]
      post_id = result.tables[:posts][:tech][:id]

      expect(votes[:post_vote][:votable_id]).to eq(post_id)
      expect(votes[:post_vote][:votable_type]).to eq("Post")
    end
  end

  describe "polymorphic associations with implicit detection" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name]

        table :activities, singular: :activity, columns: [:subject_id, :subject_type]
      end
    end

    it "auto-detects polymorphic from columns without explicit belongs_to" do
      result = FixtureBot.define(schema) do
        user :guest do
          name "Guest"
        end

        activity :created do
          subject user(:guest)
        end
      end

      activities = result.tables[:activities]
      guest_id = result.tables[:users][:guest][:id]

      expect(activities[:created][:subject_id]).to eq(guest_id)
      expect(activities[:created][:subject_type]).to eq("User")
    end
  end

  describe "polymorphic associations with multiple polymorphic columns" do
    let(:schema) do
      FixtureBot::Schema.define do
        table :users, singular: :user, columns: [:name]

        table :comments, singular: :comment, columns: [:body, :author_id, :author_type, :parent_id, :parent_type]
      end
    end

    it "detects multiple polymorphic associations" do
      result = FixtureBot.define(schema) do
        user :alice do
          name "Alice"
        end

        user :bob do
          name "Bob"
        end

        comment :reply do
          body "Reply"
          author user(:alice)
          parent user(:bob)
        end
      end

      comments = result.tables[:comments]
      alice_id = result.tables[:users][:alice][:id]
      bob_id = result.tables[:users][:bob][:id]

      expect(comments[:reply][:author_id]).to eq(alice_id)
      expect(comments[:reply][:author_type]).to eq("User")
      expect(comments[:reply][:parent_id]).to eq(bob_id)
      expect(comments[:reply][:parent_type]).to eq("User")
    end
  end

  describe FixtureBot::Key do
    it "generates deterministic IDs" do
      id1 = FixtureBot::Key.generate(:users, :admin)
      id2 = FixtureBot::Key.generate(:users, :admin)
      expect(id1).to eq(id2)
    end

    it "generates positive integers" do
      id = FixtureBot::Key.generate(:users, :admin)
      expect(id).to be > 0
    end

    it "generates different IDs for different records" do
      id1 = FixtureBot::Key.generate(:users, :admin)
      id2 = FixtureBot::Key.generate(:users, :reader)
      expect(id1).not_to eq(id2)
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
end
