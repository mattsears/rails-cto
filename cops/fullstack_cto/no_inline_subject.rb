# frozen_string_literal: true

module RuboCop
  module Cop
    module FullstackCto
      # Detects `subject` being assigned as a local variable inside `it` blocks.
      #
      # The correct pattern is to define `subject { }` once at the class level
      # and use `let(:attributes)` with nested `describe` blocks for variations.
      #
      # @example Bad
      #   it "returns formatted price" do
      #     subject = Fabricate.build(:plan, amount: 1200)
      #     assert_equal "$12.00 / month", subject.price_summary
      #   end
      #
      # @example Good
      #   let(:attributes) { {} }
      #   subject { Fabricate.build(:plan, **attributes) }
      #
      #   describe "with monthly interval" do
      #     let(:attributes) { { amount: 1200, interval: "month" } }
      #
      #     it "returns formatted price" do
      #       assert_equal "$12.00 / month", subject.price_summary
      #     end
      #   end
      class NoInlineSubject < Base
        MSG = "Do not assign `subject` as a local variable inside `it` blocks. " \
              "Define `subject { }` once at the class level and use " \
              "`let(:attributes)` with nested `describe` blocks for variations."

        # Fires on every local variable assignment (e.g., subject = ...)
        def on_lvasgn(node)
          return unless node.name == :subject
          return unless inside_it_block?(node)

          add_offense(node)
        end

        private

        # Walk up the AST to check if this assignment lives inside an `it` block.
        def inside_it_block?(node)
          node.each_ancestor(:block).any? do |block_node|
            block_node.method_name == :it
          end
        end
      end
    end
  end
end
