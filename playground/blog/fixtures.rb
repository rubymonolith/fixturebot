FixtureBot.define do
  user.email { |fixture| "#{fixture.key}@blog.test" }

  user :brad do
    name "Brad"
    email "brad@blog.test"
  end

  user :alice do
    name "Alice"
  end

  user :charlie do
    name "Charlie"
  end

  tag.name { |fixture| fixture.key.to_s.capitalize }

  tag :ruby
  tag :rails
  tag :testing

  post :hello_world do
    title "Hello World"
    body "Welcome to the blog!"
    author :brad
    tags :ruby, :rails
  end

  post :tdd_guide do
    title "Getting Started with TDD"
    body "Test-driven development is a practice where you write tests before code."
    author :alice
    tags :ruby, :testing
  end

  comment :great_post do
    body "Great post, thanks for sharing!"
    post :hello_world
    author :alice
  end

  comment :helpful do
    body "This was really helpful."
    post :tdd_guide
    author :charlie
  end

  comment :follow_up do
    body "Could you write a follow-up on mocking?"
    post :tdd_guide
    author :brad
  end

  vote :alice_likes_hello do
    votable post(:hello_world)
    voter :alice
  end

  vote :brad_likes_tdd do
    votable post(:tdd_guide)
    voter :brad
  end

  vote :charlie_likes_great_post do
    votable comment(:great_post)
    voter :charlie
  end
end
