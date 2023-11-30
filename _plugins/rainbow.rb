# frozen_string_literal: true

require "rainbow/refinement"

module Jekyll
  module RainbowFilter
    using Rainbow

    VALID_COLORS = Rainbow::Color::Named.color_names

    def background(input, color_name)
      symbolized_name = color_name.to_sym
      color_name = symbolized_name if VALID_COLORS.include?(symbolized_name)

      input.background(color_name)
    end

    alias_method :bg, :background

    def blink(input)
      input.blink
    end

    def bright(input)
      input.bright
    end

    def color(input, color_name)
      symbolized_name = color_name.to_sym
      color_name = symbolized_name if VALID_COLORS.include?(symbolized_name)

      input.color(color_name)
    end

    def cross_out(input)
      input.cross_out
    end

    def faint(input)
      input.faint
    end

    def hide(input)
      input.hide
    end

    def inverse(input)
      input.inverse
    end

    def italic(input)
      input.italic
    end

    def strike(input)
      input.strike
    end

    def underline(input)
      input.underline
    end
  end
end

Liquid::Template.register_filter(Jekyll::RainbowFilter)
