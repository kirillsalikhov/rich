require 'cgi'
require 'mime/types'
require 'kaminari'

module Rich
  class RichFile < ActiveRecord::Base

    scope :images,  -> { where("rich_rich_files.simplified_type = 'image'") }
    scope :files,   -> { where("rich_rich_files.simplified_type = 'file'") }

    include Kaminari::ConfigurationMethods
    paginates_per Rich.options[:paginates_per]

    has_attached_file :rich_file,
                      :styles => Proc.new {|a| a.instance.set_styles },
                      :convert_options => Proc.new { |a| Rich.convert_options[a] }
    if self.respond_to?(:do_not_validate_attachment_file_type)
      do_not_validate_attachment_file_type :rich_file
    end
    validates_attachment_presence :rich_file
    validate :check_content_type
    validates_attachment_size :rich_file, :less_than=>15.megabyte, :message => "must be smaller than 15MB"

    before_create :clean_file_name

    after_create :cache_style_uris_and_save
    before_update :cache_style_uris




    def set_styles
      if self.simplified_type=="image"
        Rich.image_styles
      else
        {}
      end
    end

    private

    def cache_style_uris_and_save
      cache_style_uris
      self.save!
    end

    def cache_style_uris
      uris = {}

      rich_file.styles.each do |style|
        uris[style[0]] = rich_file.url(style[0].to_sym, false)
      end

      # manualy add the original size
      uris["original"] = rich_file.url(:original, false)

      self.uri_cache = uris.to_json
    end

    def clean_file_name
      extension = File.extname(rich_file_file_name).gsub(/^\.+/, '')
      filename = rich_file_file_name.gsub(/\.#{extension}$/, '')

      filename = CGI::unescape(filename)
      filename = CGI::unescape(filename)

      extension = extension.downcase
      filename = filename.downcase.gsub(/[^a-z0-9]+/i, '-')

      self.rich_file.instance_write(:file_name, "#{filename}.#{extension}")
    end

    def check_content_type
      self.rich_file.instance_write(:content_type, MIME::Types.type_for(rich_file_file_name)[0].content_type)

      unless Rich.validate_mime_type(self.rich_file_content_type, self.simplified_type)
        self.errors[:base] << "'#{self.rich_file_file_name}' is not the right type."
      end
    end

  end
end
