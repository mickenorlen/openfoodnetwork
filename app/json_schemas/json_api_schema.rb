# frozen_string_literal: true

class JsonApiSchema
  class << self
    def attributes
      {}
    end

    def required_attributes
      []
    end

    def relationships
      []
    end

    def all_attributes
      attributes.keys
    end

    def schema(options = {})
      {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: data_properties(**options)
          },
          meta: { type: :object },
          links: { type: :object }
        },
        required: [:data]
      }
    end

    def collection(options)
      {
        type: :object,
        properties: {
          data: {
            type: :array,
            items: {
              type: :object,
              properties: data_properties(**options)
            }
          },
          meta: {
            type: :object,
            properties: {
              pagination: {
                type: :object,
                properties: {
                  results: { type: :integer, example: 250 },
                  pages: { type: :integer, example: 5 },
                  page: { type: :integer, example: 2 },
                  per_page: { type: :integer, example: 50 },
                }
              }
            },
            required: [:pagination]
          },
          links: {
            type: :object,
            properties: {
              self: { type: :string },
              first: { type: :string },
              prev: { type: :string, nullable: true },
              next: { type: :string, nullable: true },
              last: { type: :string }
            }
          }
        },
        required: [:data, :meta, :links]
      }
    end

    private

    def data_properties(require_all: false, with: nil)
      with_result = get_with(with)
      attributes = get_attributes(with_result)
      required = get_required(require_all, with, with_result)

      {
        id: { type: :string, example: "1" },
        type: { type: :string, example: object_name },
        attributes: {
          type: :object,
          properties: attributes,
          required: required
        },
        relationships: {
          type: :object,
          properties: relationships.to_h do |name|
            [
              name,
              relationship_schema(name)
            ]
          end
        }
      }
    end

    # Example
    # with: :my_method
    # => with_result = my_method
    # => attributes = attributes.merge(with_result)
    #
    # with: {name: :my_method, required: true, opts: {method_opt: true}}
    # => with_result = my_method({method_opt: true})
    # => attributes = attributes.merge(with_result)
    # => required += with_result.keys
    #
    # with: [:my_method, :another_method]
    # => with_result = my_method.merge(another_method)
    # => attributes = attribtues.merge(with_result)
    #
    # To test use eg::
    # => MySchema.collection(..., with: ...)
    #     .dig(:properties, :data, :items, :properties, :attributes)
    def get_with(with)
      case with
      when Symbol
        public_send(with)
      when Hash
        with[:opts] && public_send(with[:name], with[:opts]) || public_send(with[:name])
      when Array
        obj = {}

        with.each do |w|
          obj.merge!(get_with(w))
        end

        obj
      end
    end

    def get_required(require_all, with, with_result)
      required = require_all ? all_attributes : required_attributes

      if with.is_a?(Hash) && with[:required] == true && with_result.present?
        required += with_result.keys
      end

      required
    end

    def get_attributes(with_result)
      if [with_result, attributes].all?{ |obj| obj.respond_to?(:merge) }
        attributes.merge(with_result)
      else
        attributes
      end
    end

    def relationship_schema(name)
      if is_singular?(name)
        RelationshipSchema.schema(name)
      else
        RelationshipSchema.collection(name)
      end
    end

    def is_singular?(name)
      name.to_s.singularize == name.to_s
    end
  end
end
