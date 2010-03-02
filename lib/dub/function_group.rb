module Dub
  class FunctionGroup < Array
    def initialize(parent, gen = nil)
      @parent, @gen = parent, gen
    end

    def bind(generator)
      @gen = generator.function_generator
    end

    def generator
      @gen || (@parent && @parent.function_generator)
    end

    alias gen generator

    def to_s
      generator.group(self)
    end

    def name
      first.name
    end

    def method_name(overloaded_index = nil)
      first.method_name(overloaded_index)
    end

    def map(&block)
      list = self.class.new(@parent, @gen)
      super(&block).each do |e|
        list << e
      end
      list
    end

    def compact
      list = self.class.new(@parent, @gen)
      super.each do |e|
        list << e
      end
      list
    end

    def overloaded_index
      nil
    end

    def prefix
      first.prefix
    end

    def <=>(other)
      name <=> other.name
    end
  end
end