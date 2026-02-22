FixtureBot::Schema.define do
  table :users, singular: :user, columns: [:name, :email]

  table :posts, singular: :post, columns: [:title, :body, :author_id] do
    belongs_to :author, table: :users
  end

  table :comments, singular: :comment, columns: [:body, :post_id, :author_id] do
    belongs_to :post, table: :posts
    belongs_to :author, table: :users
  end

  table :votes, singular: :vote, columns: [:user_id, :votable_id, :votable_type] do
    belongs_to :user, table: :users
  end

  table :tags, singular: :tag, columns: [:name]

  join_table :posts_tags, :posts, :tags
end
