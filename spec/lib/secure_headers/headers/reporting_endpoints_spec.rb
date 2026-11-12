# frozen_string_literal: true
require "spec_helper"

module SecureHeaders
  describe ReportingEndpoints do
    describe "#make_header" do
      it "returns nil when config is nil" do
        expect(ReportingEndpoints.make_header(nil)).to be_nil
      end

      it "returns nil when config is OPT_OUT" do
        expect(ReportingEndpoints.make_header(OPT_OUT)).to be_nil
      end

      it "formats a single endpoint" do
        config = { "csp-endpoint" => "https://example.com/csp-reports" }
        header_name, value = ReportingEndpoints.make_header(config)
        expect(header_name).to eq("reporting-endpoints")
        expect(value).to eq('csp-endpoint="https://example.com/csp-reports"')
      end

      it "formats a single endpoint with a symbol" do
        config = { "csp-endpoint": "https://example.com/csp-reports" }
        header_name, value = ReportingEndpoints.make_header(config)
        expect(header_name).to eq("reporting-endpoints")
        expect(value).to eq('csp-endpoint="https://example.com/csp-reports"')
      end

      it "formats multiple endpoints" do
        config = {
          "csp-endpoint" => "https://example.com/csp-reports",
          "permissions-endpoint" => "https://example.com/permissions-reports"
        }
        header_name, value = ReportingEndpoints.make_header(config)
        expect(header_name).to eq("reporting-endpoints")
        expect(value).to eq(
          'csp-endpoint="https://example.com/csp-reports", ' \
          'permissions-endpoint="https://example.com/permissions-reports"'
        )
      end

      it "serializes endpoints in a stable order regardless of hash order" do
        first = {
          "z-endpoint" => "https://example.com/z",
          "a-endpoint" => "https://example.com/a",
          "m-endpoint" => "https://example.com/m"
        }
        second = {
          "m-endpoint" => "https://example.com/m",
          "a-endpoint" => "https://example.com/a",
          "z-endpoint" => "https://example.com/z"
        }

        expect(ReportingEndpoints.make_header(first).last).to eq(
          ReportingEndpoints.make_header(second).last
        )
        expect(ReportingEndpoints.make_header(first).last).to eq(
          'a-endpoint="https://example.com/a", ' \
          'm-endpoint="https://example.com/m", ' \
          'z-endpoint="https://example.com/z"'
        )
      end

      it "validates that endpoints are present" do
        expect do
          ReportingEndpoints.validate_config!({})
        end.to_not raise_error
      end

      it "omits the header for an empty endpoint dictionary" do
        expect(ReportingEndpoints.make_header({})).to be_nil
      end
    end

    describe "#validate_config!" do
      it "accepts nil" do
        expect do
          ReportingEndpoints.validate_config!(nil)
        end.to_not raise_error
      end

      it "accepts OPT_OUT" do
        expect do
          ReportingEndpoints.validate_config!(OPT_OUT)
        end.to_not raise_error
      end

      it "accepts valid endpoint configuration" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-violations" => "https://example.com/reports"
          })
        end.to_not raise_error
      end

      it "accepts valid endpoint configuration with symbol keys" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-violations": "https://example.com/reports"
          })
        end.to_not raise_error
      end

      it "accepts endpoint names with every structured-field key character" do
        expect do
          ReportingEndpoints.validate_config!({
            "a.z_9-*" => "https://example.com/reports"
          })
        end.to_not raise_error
      end

      it "rejects non-hash config" do
        expect do
          ReportingEndpoints.validate_config!("not a hash")
        end.to raise_error(TypeError)
      end

      it "rejects empty endpoint name" do
        expect do
          ReportingEndpoints.validate_config!({
            "" => "https://example.com/reports"
          })
        end.to raise_error(ReportingEndpointsConfigError)
      end

      it "rejects non-string endpoint name" do
        expect do
          ReportingEndpoints.validate_config!({
            123 => "https://example.com/reports"
          })
        end.to raise_error(ReportingEndpointsConfigError)
      end

      it "rejects endpoint names containing quotes or dictionary delimiters" do
        invalid_names = [
          'csp"endpoint',
          "csp,endpoint",
          "csp;endpoint",
          "csp endpoint",
          "CSP-endpoint"
        ]

        invalid_names.each do |name|
          expect do
            ReportingEndpoints.validate_config!({
              name => "https://example.com/reports"
            })
          end.to raise_error(ReportingEndpointsConfigError, /structured-field key/)
        end
      end

      it "rejects duplicate endpoint names after symbol normalization" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-endpoint" => "https://example.com/reports",
            :"csp-endpoint" => "https://example.com/other-reports"
          })
        end.to raise_error(ReportingEndpointsConfigError, /Duplicate endpoint name/)
      end

      it "rejects empty endpoint URL" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-endpoint" => ""
          })
        end.to raise_error(ReportingEndpointsConfigError)
      end

      it "rejects non-string endpoint URL" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-endpoint" => 123
          })
        end.to raise_error(ReportingEndpointsConfigError)
      end

      it "rejects non-https URLs" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-endpoint" => "http://example.com/reports"
          })
        end.to raise_error(ReportingEndpointsConfigError, /must use https/)
      end

      it "rejects endpoint URLs containing structured-field or header delimiters" do
        invalid_urls = [
          'https://example.com/reports"',
          "https://example.com/reports,evil",
          "https://example.com/reports\r\nInjected: yes",
          "https://example.com/reports\nInjected: yes",
          "https://example.com/reports\\evil"
        ]

        invalid_urls.each do |url|
          expect do
            ReportingEndpoints.validate_config!({
              "csp-endpoint" => url
            })
          end.to raise_error(ReportingEndpointsConfigError, /structured-field string/)
        end
      end

      it "rejects endpoint URLs that are not valid absolute URIs" do
        expect do
          ReportingEndpoints.validate_config!({
            "csp-endpoint" => "https://"
          })
        end.to raise_error(ReportingEndpointsConfigError, /must use https/)
      end
    end
  end
end
