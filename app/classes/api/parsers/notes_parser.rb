class API
  module Parsers
    # Parse API notes
    class NotesParser < StringParser
      def parse(str)
        return Observation.no_notes if str.empty?
        { Observation.other_notes_key => str }
      end
    end
  end
end
