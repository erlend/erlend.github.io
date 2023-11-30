# frozen_string_literal: true

require "word_wrap"

module Jekyll
  module WordWrapFilter
    def wrap(input, line_width = 42)
      WordWrap.ww input, line_width
    end
  end
end

Liquid::Template.register_filter(Jekyll::WordWrapFilter)
