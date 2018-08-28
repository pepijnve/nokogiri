require 'nokogiri'

module Nokogiri
  # Monkey patch
  module XML
    class Node
      # HTML elements can have attributes that contain colons.
      # Nokogiri::XML::Node#[]= treats names with colons as a prefixed QName
      # and tries to create an attribute in a namespace. This is especially
      # annoying with attribute names like xml:lang since libxml2 will
      # actually create the xml namespace if it doesn't exist already.
      define_method(:add_child_node_and_reparent_attrs) do |node|
        add_child_node(node)
        node.attribute_nodes.find_all { |a| a.namespace }.each do |attr|
          attr.remove
          node[attr.name] = attr.value
        end
      end

      def inner_html(options = {})
        result = options[:preserve_newline] && HTML5.prepend_newline?(self) ? "\n" : ""
        result << children.map { |child| child.to_html(options) }.join
        result
      end

      def write_to(io, *options)
        options = options.first.is_a?(Hash) ? options.shift : {}
        encoding = options[:encoding] || options[0]
        if Nokogiri.jruby?
          save_options = options[:save_with] || options[1]
          indent_times = options[:indent] || 0
        else
          save_options = options[:save_with] || options[1] || SaveOptions::FORMAT
          indent_times = options[:indent] || 2
        end
        indent_string = (options[:indent_text] || ' ') * indent_times

        config = SaveOptions.new(save_options.to_i)
        yield config if block_given?

        config_options = config.options
        if (config_options & (SaveOptions::AS_XML | SaveOptions::AS_XHTML) != 0) || !document.is_a?(HTML5::Document)
          # Use Nokogiri's serializing code.
          native_write_to(io, encoding, indent_string, config_options)
        else
          # Serialize including the current node.
          encoding ||= document.encoding || Encoding::UTF_8
          internal_ops = {
            trailing_nl: config_options & SaveOptions::FORMAT != 0,
            preserve_newline: options[:preserve_newline] || false
          }
          HTML5.serialize_node_internal(self, io, encoding, options)
        end
      end
    end
  end
end
