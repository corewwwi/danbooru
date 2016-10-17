module Danbooru
  module Extensions
    module ActiveRecordApi
      extend ActiveSupport::Concern

      def serializable_hash(options = {})
        options ||= {}
        options[:except] ||= []
        options[:except] += hidden_attributes
        super(options)
      end

      def to_xml(options = {}, &block)
        # to_xml ignores serializable_hash
        options ||= {}
        options[:except] ||= []
        options[:except] += hidden_attributes
        super(options, &block)
      end

    protected
      def hidden_attributes
        [:uploader_ip_addr, :updater_ip_addr, :creator_ip_addr, :ip_addr]
      end
    end
  end
end

class Delayed::Job
  def hidden_attributes
    [:handler]
  end
end

class ActiveRecord::Relation
  # Normally @wiki_pages.to_xml returns `<nil-classes type="array"/>` if
  # @wiki_pages is empty. We don't want that. This makes the root element
  # default to the table name (e.g. wiki-page-versions) instead.
  def to_xml(options = {}, &block)
    options[:root] ||= self.table_name.tableize.dasherize

    super(options, &block)
  end
end

class ActiveRecord::Base
  include Danbooru::Extensions::ActiveRecordApi
end
