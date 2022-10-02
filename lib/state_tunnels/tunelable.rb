# frozen_string_literal: true

module StateTunnels
  module Tunelable
     def self.included(base)
      base.send(:extend, ClassMethods)
      base.send(:include, InstanceMethods)
      base.prepend(Initializer)
    end
  
    module Initializer
      def initialize(*)
      end
    end
  
    module ClassMethods
      # -Adds ability to configure state machine with enum_transitions method.
      # -Adds to_{state_value}? boolean method, that evaluate transition to specific state value.
      # -Triggers described tunnels validation for confirming given transaction.
      #
      # Example:
      #   class Order
      #     include StateTunnels::Tunelable
      #     enum state: { NA: 'na', PROGRESS: 'in_progress', DISPATCHED: 'dispatched'}
      #
      #     STATES = states.keys.map(&:to_sym)
      #
      #    # rules hash
      #    #
      #    # key: target state, sym
      #    # value: rules, hash =
      #    #  from: states list from which transition is allowed, [sym] (optional)
      #    #  if: method name which also checks if transition is eligible, [sym] (optional)
      #
      #
      #     enum_transitions for: STATES, with: {
      #                             PROGRESS: { from: [:NA], if: :can_be_progressed? },
      #                             DISPATCHED: { from: [:PROGRESS] }
      #                           }
      #
      #     def can_be_progressed?
      #       # code that checks some additional conditions if Order is able to be turned to PROGRESS
      #     end
      #   end
      #
      # Arguments:
      #   with: hash, transition rules
      #   field: symbol, name of the model enum which will be considered as a state. Default value is :state
      #   for: list of the states, [symbol]
      def enum_transitions(**props)
        field_name = props[:field] || :state
        transition_rules = props[:with] || {}
        states_list = props[:states] || []

        add_state_transitions_method?(field_name, transition_rules)
        add_state_transitions_method(field_name)
        add_to_state_methods(states_list)

        send(:validate, :state_transitions, if: "#{field_name}_changed?".to_sym)
      end

      def add_state_transitions_method?(field_name, transition_rules)
        define_method :state_transitions? do |args = {}|
          target_state = (args[:target] || send(field_name))&.to_sym
          was_state = send("#{field_name}_was")&.to_sym
          allowed_from_states = transition_rules.dig(target_state, :from)
          if_condition = transition_rules.dig(target_state, :if)
          condition_result = !if_condition || fire_it(if_condition, args)
          allowed_from_states ? (allowed_from_states.include?(was_state) && condition_result) : condition_result
        end
      end

      def add_state_transitions_method(field_name)
        define_method :state_transitions do
          return true if state_transitions?

          errors.add(field_name, "invalid transition from #{send("#{field_name}_was")} to #{send(field_name)}")
        end
      end

      def add_to_state_methods(states_list)
        states_list.each do |to_state|
          define_method("to_#{to_state.downcase}?".to_sym) do |args = {}|
            state_transitions?(target: to_state, self: self, props: args)
          end
        end
      end

      ## un-applied helper method(s), (unused/untested) ##

      ## fire!
      # Alternative state transition method to traditional model_instance.{state}!
      # - turn to state
      # - returns boolean instead of throwing exception
      # - performs consequent transitions from given list of states from the args

      #  Examples:
      #
      # single call:
      # > order.fire! :PROGRESS
      # > true
      # > order.state
      # > :PROGRESS
      # will try to turn order state to PROGRESS, and returns corresponding boolean result
      #
      # consequent call until successful:
      # > order.fire! :NA, :PROGRESS
      # > true
      # > order.state
      # > :NA
      # will try to turn listed order states consequently until first successful and return boolean result
      # if there were no successful, returns false, otherwise true
      #
      # consequent call through all:
      # > order.fire! :NA, :PROGRESS, clear: true
      # > true
      # > order.state
      # > :PROGRESS
      # will try to turn all listed order states in the arguments consequently and return boolean result
      # if there were no successful, returns false, otherwise true
      #
      # Arguments:
      #   states: array, [states] for consequent call. Will raise ArgumentError if there are invalid states in the list.
      #   arguments: hash, optional arguments
      #     clear: true (false by default). Flag for allowing method tries turning all given states, neglecting result.
      def add_fire_method
        define_method :fire! do |*states, **options|
          raise ArgumentError, 'Wrong state list!' if states.any? { |state| !respond_to?("#{state}!") }

          clear = options[:clear] || false
          result = false
          states.each do |state|
            next unless send("to_#{state.downcase}?")

            send("#{state}!")
            result = true
            next if clear

            break
          end
          result
        end
      end
    end
  
    module InstanceMethods
      private

      def condition(if_condition_method)
        if_condition_method && respond_to?(if_condition_method) ? send(if_condition_method) : true
      end

      def fire_it(handler, args = {})
        if handler.respond_to?(:call)
          handler.call(args)
        elsif handler && respond_to?(handler)
          send(handler)
        end
      end
    end
   end
end
