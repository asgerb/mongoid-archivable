require 'active_support/concern'

module Mongoid
  module Archivable

    extend ActiveSupport::Concern

    module Restoration
      # Restores the archived document to its former glory.
      def restore
        original_document.save
      end

      def original_document
        self.original_type.constantize.new(attributes.except("_id", "original_id", "original_type", "archived_at")) do |doc|
          doc.id = self.original_id
        end
      end

      private

      def original_class_name
        return self.original_type if self.respond_to?(:original_type) && self.original_type.present?
        self.class.to_s.gsub(/::Archive\z/, '')
      end
    end

    included do
      self.const_set("Archive", Class.new)
      self.const_get("Archive").class_eval do
        include Mongoid::Document
        include Mongoid::Attributes::Dynamic
        include Mongoid::Archivable::Restoration
        field :archived_at, type: Time
        field :original_id, type: String
        field :original_type, type: String
      end

      before_destroy :archive
    end

    private

    def archive
      self.class.const_get("Archive").create(attributes.except("_id", "_type")) do |doc|
        doc.original_id = self.id
        doc.original_type = self.class.to_s
        doc.archived_at = Time.now.utc
      end
    end

  end
end
