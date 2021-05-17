module GraphQL
  class Guard
    class TraceMetaData
      attr_reader :metadata

      def initialize(metadata)
        @metadata = metadata
      end

      def object
        metadata[:object].object
      end

      def context
        metadata[:query].context
      end

      def ctx
        context
      end

      def args
        if metadata[:arguments].key?(:input) && !metadata[:arguments][:input].is_a?(Hash)
          return metadata[:arguments][:input] # Relay mutation input
        end

        metadata[:arguments]
      end

      def type
        metadata[:field].owner
      end

      def field
        metadata[:field].name.to_sym
      end

      def path
        "#{type}.#{field}"
      end
    end
  end
end
