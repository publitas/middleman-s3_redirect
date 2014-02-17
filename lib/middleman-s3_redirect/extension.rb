require 'middleman-core'

module Middleman
  module S3Redirect
    class Options < Struct.new(
      :prefix,
      :public_path,
      :bucket,
      :region,
      :path_style,
      :aws_access_key_id,
      :aws_secret_access_key,
      :after_build
    )

      def s3_redirect(from, to)
        s3_redirects << RedirectEntry.new(from, to)
      end

      def s3_redirects
        @s3_redirects ||= []
      end

      protected
      class RedirectEntry
        attr_reader :from, :to
        def initialize(from, to)
          @from = from
          @to = to
        end
      end

    end

    class << self
      def options
        @@options
      end

      def registered(app, options_hash = {}, &block)
        options = Options.new(options.hash)
        yield options if block_given?

        @@options = options

        app.send :include, Helpers

        options.public_path ||= "build"
        options.path_style = true if options.path_style.nil?

        app.after_configuration do |config|
          after_build do |builder|
            ::Middleman::S3Redirect.generate if options.after_build
          end
        end
      end
      alias :included :registered

      def generate
        options.s3_redirects.each do |redirect|
          puts "Redirecting #{redirect.from} to #{redirect.to}"
          bucket.files.create({
            :key => redirect.from,
            :public => true,
            :acl => 'public-read',
            :body => '',
            'x-amz-website-redirect-location' => "#{redirect.to}"
          })
        end
      end

      def connection
        @connection ||= Fog::Storage.new({
          :provider => 'AWS',
          :aws_access_key_id => options.aws_access_key_id,
          :aws_secret_access_key => options.aws_secret_access_key,
          :region => options.region,
          :path_style => options.path_style
        })
      end

      def bucket
        @bucket ||= connection.directories.get(options.bucket)
      end

      def s3_files
        @s3_files ||= bucket.files
      end

      module Helpers
        def s3_redirect(from, to)
          s3_redirect_options.s3_redirect(from, to)
        end

        def s3_redirect_options
          ::Middleman::S3Redirect.options
        end
      end
    end
  end
end
