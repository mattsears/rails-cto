# frozen_string_literal: true

module RuboCop
  module Cop
    module Minitest
      # Ensures every test class defines a `subject { }` block at the class level.
      #
      # A test file without `subject` is incomplete. The `subject` block declares
      # the primary object under test and prevents re-instantiating it inline
      # across `it` blocks.
      #
      # Only enforced for classes inheriting from `ActiveSupport::TestCase` or
      # `ViewComponent::TestCase` whose name ends in "Test".
      #
      # @example Bad
      #   class BookmarkTest < ActiveSupport::TestCase
      #     describe "#host" do
      #       it "returns the host" do
      #         bookmark = Fabricate.build(:bookmark)
      #         assert_equal "example.com", bookmark.host
      #       end
      #     end
      #   end
      #
      # @example Good
      #   class BookmarkTest < ActiveSupport::TestCase
      #     subject { Fabricate.build(:bookmark, url: "https://example.com") }
      #
      #     describe "#host" do
      #       it "returns the host" do
      #         assert_equal "example.com", subject.host
      #       end
      #     end
      #   end
      class SubjectRequired < Base
        MSG = "Test class `%<class_name>s` must define a `subject { }` block at the class level."

        ENFORCED_SUPERCLASSES = %w[
          ActiveSupport::TestCase
          ViewComponent::TestCase
        ].freeze

        # Fires on every class definition.
        def on_class(node)
          return unless enforced_test_class?(node)
          return if has_subject_block?(node)

          class_name = node.identifier.const_name
          add_offense(node.identifier, message: format(MSG, class_name: class_name))
        end

        private

        # Check if this class ends in "Test" and inherits from an enforced superclass.
        def enforced_test_class?(node)
          return false unless node.parent_class
          return false unless node.identifier.const_name&.end_with?("Test")

          superclass_name = resolve_const_name(node.parent_class)
          ENFORCED_SUPERCLASSES.include?(superclass_name)
        end

        # Resolve a constant node to its full name (e.g., ActiveSupport::TestCase).
        def resolve_const_name(const_node)
          return nil unless const_node

          names = []
          current = const_node
          while current&.const_type?
            names.unshift(current.short_name.to_s)
            current = current.namespace if current.respond_to?(:namespace)
            break if current == const_node || !current&.const_type?
          end
          names.join("::")
        end

        # Check if any descendant of the class body is a `subject` block.
        def has_subject_block?(class_node)
          return false unless class_node.body

          class_node.body.each_descendant(:block).any? do |block_node|
            block_node.method_name == :subject
          end
        end
      end
    end
  end
end
