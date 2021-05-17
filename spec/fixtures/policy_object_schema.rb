# frozen_string_literal: true

module PolicyObject
  class PostType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :title, String, null: true
  end

  class QueryType < GraphQL::Schema::Object
    field :posts, [PostType], null: false do
      argument :user_id, ID, required: true
    end

    def posts(user_id:)
      Post.where(user_id: user_id)
    end
  end

  class BaseMutationType < GraphQL::Schema::RelayClassicMutation
  end

  class CreatePostMutation < BaseMutationType
    null true
    argument :user_id, ID, required: true
    field :post, PostType, null: true

    def resolve(user_id:)
      {post: Post.new(user_id: user_id)}
    end
  end

  class MutationType < GraphQL::Schema::Object
    field :create_post, mutation: CreatePostMutation
  end

  class GraphqlPolicy
    RULES = {
      QueryType => {
        posts: ->(data) { data.args[:user_id] == data.ctx[:current_user].id }
      },
      PostType => {
        '*': ->(data) { data.ctx[:current_user].admin? }
      },
      MutationType => {
        createPost: ->(data) { data.args[:user_id] == data.ctx[:current_user].id }
      }
    }

    def self.guard(type, field)
      RULES.dig(type, field)
    end
  end

  class Schema < GraphQL::Schema
    use GraphQL::Execution::Interpreter
    use GraphQL::Analysis::AST
    query QueryType
    mutation MutationType
    use GraphQL::Guard.new(policy_object: GraphqlPolicy)
  end
end
