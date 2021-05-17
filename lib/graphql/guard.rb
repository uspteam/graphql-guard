# frozen_string_literal: true

require "graphql"
require "graphql/guard/version"
require "graphql/guard/trace_meta_data"

module GraphQL
  class Guard
    NotAuthorizedError = Class.new(StandardError)

    ANY_FIELD_NAME = :'*'

    DEFAULT_NOT_AUTHORIZED = ->(data) do
      raise NotAuthorizedError.new("Not authorized to access: #{data.path}")
    end

    MASKING_FILTER = ->(schema_member, ctx) do
      if schema_member.respond_to?(:mask) && schema_member.mask
        return schema_member.mask.first.call(ctx) 
      end

      true
    end

    attr_reader :policy_object, :not_authorized

    def initialize(policy_object: nil, not_authorized: DEFAULT_NOT_AUTHORIZED)
      @policy_object = policy_object
      @not_authorized = not_authorized
    end

    def use(schema_definition)
      if schema_definition.interpreter?
        schema_definition.tracer(self)
      else
        raise "Please use the graphql gem version >= 1.10 with GraphQL::Execution::Interpreter"
      end

      add_schema_masking!(schema_definition)
    end

    def trace(event, trace_data)
      if event == 'execute_field'
        ensure_guarded(trace_data) { yield }
      else
        yield
      end
    end

    def find_guard_proc(type, field)
      return unless type.respond_to?(:type_class)

      inline_guard(field) ||
        policy_object_guard(type.type_class, field.name.to_sym) ||
        inline_guard(type) ||
        policy_object_guard(type.type_class, ANY_FIELD_NAME)
    end

    private

    def add_schema_masking!(schema_definition)
      schema_definition.class_eval do
        def self.default_filter
          GraphQL::Filter.new(except: default_mask).merge(only: MASKING_FILTER)
        end
      end
    end

    def ensure_guarded(trace_data)
      guard_proc = find_guard_proc(trace_data[:field].owner, trace_data[:field])
      return yield unless guard_proc

      trace_meta = GraphQL::Guard::TraceMetaData.new(trace_data)

      if guard_proc.call(trace_meta)
        yield
      else
        not_authorized.call(trace_meta)
      end
    end

    def policy_object_guard(type, field_name)
      @policy_object && @policy_object.guard(type, field_name)
    end

    def inline_guard(type_or_field)
      if type_or_field.respond_to?(:guard) && type_or_field.guard
        type_or_field.guard.first
      end
    end
  end
end

GraphQL::Schema::Object.accepts_definition(:guard)
GraphQL::Schema::Field.accepts_definition(:guard)
GraphQL::Schema::Field.accepts_definition(:mask)
