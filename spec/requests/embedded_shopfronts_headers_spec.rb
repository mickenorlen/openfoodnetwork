# frozen_string_literal: true

require 'spec_helper'

describe "setting response headers for embedded shopfronts", type: :request do
  include AuthenticationHelper

  let(:enterprise) { create(:distributor_enterprise) }
  let(:user) { enterprise.owner }

  before do
    login_as(user)
  end

  context "with embedded shopfront disabled" do
    before do
      Spree::Config[:enable_embedded_shopfronts] = false
    end

    it "disables external embedding by default" do
      get shops_path
      expect(response.status).to be 200
      expect(response.headers['X-Frame-Options']).to be_nil
      expect(response.headers['Content-Security-Policy']).to include "frame-ancestors 'self' ;"
    end
  end

  context "with embedded shopfronts enabled" do
    before do
      Spree::Config[:enable_embedded_shopfronts] = true
    end

    context "but no whitelist" do
      before do
        Spree::Config[:embedded_shopfronts_whitelist] = ""
      end

      it "disables external embedding" do
        get shops_path
        expect(response.status).to be 200
        expect(response.headers['Content-Security-Policy']).to include "frame-ancestors 'self' ;"
      end
    end

    context "with a valid whitelist" do
      before do
        Spree::Config[:embedded_shopfronts_whitelist] = "example.com external-site.com"
        allow_any_instance_of(ActionDispatch::Request).to receive(:referer).and_return('http://external-site.com/shop?embedded_shopfront=true')
      end

      it "allows iframes on certain pages when enabled in configuration" do
        get enterprise_shop_path(enterprise) + '?embedded_shopfront=true'

        expect(response.status).to be 200
        expect(response.headers['Content-Security-Policy']).to include "frame-ancestors 'self' external-site.com"
      end

      it "doesn't allow iframes on other pages" do
        get spree.admin_dashboard_path

        expect(response.status).to be 200
        expect(response.headers['Content-Security-Policy']).to include "frame-ancestors 'none'"
      end
    end

    context "with www prefix" do
      before do
        Spree::Config[:embedded_shopfronts_whitelist] = "example.com external-site.com"
        allow_any_instance_of(ActionDispatch::Request).to receive(:referer).and_return('http://www.external-site.com/shop?embedded_shopfront=true')
      end

      it "matches the URL structure in the header" do
        get enterprise_shop_path(enterprise) + '?embedded_shopfront=true'

        expect(response.status).to be 200
        expect(response.headers['Content-Security-Policy']).to include "frame-ancestors 'self' www.external-site.com"
      end
    end
  end
end
