# frozen_string_literal: true
require "uri"

module SecureHeaders
  class ReportingEndpointsConfigError < StandardError; end
  class ReportingEndpoints
    HEADER_NAME = "reporting-endpoints".freeze
    ENDPOINT_NAME_REGEX = /\A(?:[a-z*])[a-z0-9._*-]*\z/.freeze
    INVALID_URL_CHARACTER_REGEX = /[\x00-\x20\x7F"\\,]/n.freeze

    class << self
      # Public: generate a Reporting-Endpoints header.
      #
      # The config should be a Hash of endpoint names to URLs.
      # Example: { "csp-endpoint" => "https://example.com/reports" }
      #
      # Returns nil if config is OPT_OUT or nil, or a header name and
      # formatted header value based on the config.
      def make_header(config = nil)
        return if config.nil? || config == OPT_OUT
        validate_config!(config)
        return if config.empty?

        [HEADER_NAME, format_endpoints(config)]
      end

      def validate_config!(config)
        case config
        when nil, OPT_OUT
          # valid
        when Hash
          names = {}
          normalized_endpoints(config).each do |name, url|
            if names.key?(name)
              raise ReportingEndpointsConfigError.new("Duplicate endpoint name: #{name.inspect}")
            end
            names[name] = true

            validate_endpoint_url!(url)
          end
        else
          raise TypeError.new("Must be a Hash of endpoint names to URLs. Found #{config.class}: #{config}")
        end
      end

      def valid_endpoint_name?(name)
        name.is_a?(String) && ENDPOINT_NAME_REGEX.match?(name)
      end

      def normalized_endpoint_name(name)
        name.is_a?(Symbol) ? name.to_s : name
      end

      def normalized_endpoints(config)
        config.each_pair.map do |raw_name, url|
          name = normalized_endpoint_name(raw_name)
          unless name.is_a?(String) && !name.empty?
            raise ReportingEndpointsConfigError.new("Endpoint name must be a non-empty string, got: #{name.inspect}")
          end
          unless valid_endpoint_name?(name)
            raise ReportingEndpointsConfigError.new(
              "Endpoint name must be a valid structured-field key (lowercase letters, digits, \"_\", \"-\", \".\", or \"*\", starting with a letter or \"*\"), got: #{raw_name.inspect}"
            )
          end

          [name, url]
        end
      end

      private

      def format_endpoints(config)
        normalized_endpoints(config).sort_by(&:first).map do |name, url|
          "#{name}=\"#{url}\""
        end.join(", ")
      end

      def validate_endpoint_url!(url)
        unless url.is_a?(String) && !url.empty?
          raise ReportingEndpointsConfigError.new("Endpoint URL must be a non-empty string, got: #{url.inspect}")
        end

        unless url.ascii_only? && !url.match?(INVALID_URL_CHARACTER_REGEX)
          raise ReportingEndpointsConfigError.new(
            "Endpoint URL must be a structured-field string and cannot contain whitespace, control characters, quotes, backslashes, or commas, got: #{url.inspect}"
          )
        end

        uri = URI.parse(url)
        unless uri.scheme&.downcase == "https" && uri.host && !uri.host.empty?
          raise ReportingEndpointsConfigError.new("Endpoint URLs must use https, got: #{url.inspect}")
        end
      rescue URI::InvalidURIError
        raise ReportingEndpointsConfigError.new("Endpoint URL is not a valid URI, got: #{url.inspect}")
      end
    end
  end
end
