module Danbooru
  module Extensions
    module String
      def to_escaped_for_sql_like
        gsub(/\\/, '\0\0').gsub(/(%|_)/, "\\\\\\1").gsub(/\*/, '%')
      end

      def to_escaped_for_tsquery_split
        scan(/\S+/).map(&:to_escaped_for_tsquery).join(" & ")
      end

      def to_escaped_for_tsquery
        "'#{gsub(/\0/, '').gsub(/'/, '\0\0').gsub(/\\/, '\0\0\0\0')}'"
      end
    end
  end
end

class String
  include Danbooru::Extensions::String
end

class FalseClass
  def to_i
    0
  end
end
